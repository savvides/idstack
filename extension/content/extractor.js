/**
 * Injected content script to extract course content from Canvas, Google Docs, and web pages.
 */
function detectPageType(url, document) {
  if (url.includes('instructure.com') || /\/courses\/\d+(?:[/?#]|$)/.test(url)) {
    if (document.querySelector('#assignment_show')) return 'Canvas Assignment';
    if (document.querySelector('#syllabusContainer') || url.includes('/assignments/syllabus')) return 'Canvas Syllabus';
    if (document.querySelector('#context_modules, #modules') || url.includes('/modules')) return 'Canvas Modules';
    if (document.querySelector('#rubrics')) return 'Canvas Rubric';
    return 'Canvas LMS Page';
  }
  if (url.includes('docs.google.com/document')) return 'Google Doc Syllabus';
  return 'Web Syllabus / Course Page';
}

function extractContentFromDOM(document, url = (typeof window !== 'undefined' && window.location ? window.location.href : '')) {
  // Canvas views that show student records: gradebook and SpeedGrader, grades, People
  // (course and account level), groups, discussion replies, submissions, Inbox. Checked on
  // every URL, because Canvas on a custom domain is only detected as Canvas under /courses/N.
  // Matched on the URL string: url can be '', and new URL('') throws. Function-scoped on
  // purpose: a top-level const would throw when the file is re-injected into the same world.
  const studentRecordUrl = /^https?:\/\/[^/?#]+\/(?:courses\/\d+\/(?:gradebook|grades|users|groups|discussion_topics|assignments\/\d+\/submissions)|conversations|groups\/\d+|users\/\d+|accounts\/\d+\/users)(?:[/?#]|$)/;
  if (studentRecordUrl.test(url)) {
    return {
      url,
      title: 'Student records page',
      pageType: 'Canvas Student Records',
      content: '',
      wordCount: 0,
      emptyReason: 'idstack does not read Canvas pages that show student records (grades, People, Inbox, discussions, groups, submissions). Consider auditing an assignment, page, syllabus, rubric, or Modules view instead.'
    };
  }

  const pageType = detectPageType(url, document);
  let title = (document && document.title) || 'Course Document';
  let content = '';

  if (pageType.startsWith('Canvas')) {
    const heading = document.querySelector('#assignment_show .title, .page-title, h1');
    if (heading) title = (heading.innerText || heading.textContent || '').trim();

    if (pageType === 'Canvas Modules') {
      // Every item title; querySelector alone returns only the first one.
      content = Array.from(document.querySelectorAll('.module-item-title'))
        .map((el) => (el.innerText || el.textContent || '').trim())
        .filter(Boolean)
        .join('\n');
    } else {
      const mainBody = document.querySelector('#assignment_show .description.user_content, .show-content.user_content, #syllabusContainer, #rubrics');
      // No document.body fallback on Canvas: an unmatched view can hold names, grades, or posts.
      content = mainBody ? (mainBody.innerText || mainBody.textContent || '').trim() : '';
    }
  } else if (pageType === 'Google Doc Syllabus') {
    const kixApp = document.querySelector('.kix-appview-editor');
    content = kixApp ? (kixApp.innerText || kixApp.textContent || '').trim() : (document.body ? (document.body.innerText || document.body.textContent || '').trim() : '');
  } else {
    // General web page extraction
    const article = document.querySelector('main, article, [role="main"]');
    content = article ? (article.innerText || article.textContent || '').trim() : (document.body ? (document.body.innerText || document.body.textContent || '').trim() : '');
  }

  return {
    url,
    title,
    pageType,
    content: content.slice(0, 15000),
    wordCount: content.split(/\s+/).filter(Boolean).length
  };
}

// Async, so the injection's completion value is a Promise; Chrome awaits it and the
// side panel still receives the payload.
async function extractPageContent() {
  const url = typeof window !== 'undefined' && window.location ? window.location.href : '';
  const data = extractContentFromDOM(document, url);
  // Google Docs draws its text on <canvas>, so the editor DOM holds none of it. Read the
  // plain-text export with the user's own session instead (same origin, no new permission).
  // Keep fetch's default credentials mode: the export redirects to a host that answers
  // ACAO: *, which a credentialed request would reject. Published /d/e/ docs are skipped:
  // their text is in the DOM.
  const doc = url.match(/^https:\/\/docs\.google\.com\/document\/(?:u\/\d+\/)?d\/(?!e\/)[\w-]+/);
  if (!doc) return data;
  try {
    const res = await fetch(`${doc[0]}/export?format=txt`, { signal: AbortSignal.timeout(10000) });
    // Signed out, the export answers 200 with an HTML sign-in page.
    if (!res.ok || !(res.headers.get('content-type') || '').startsWith('text/plain')) throw new Error(String(res.status));
    const text = (await res.text()).trim();
    return { ...data, content: text.slice(0, 15000), wordCount: text.split(/\s+/).filter(Boolean).length };
  } catch (e) {
    // Offline, timed out, refused, or not plain text.
    return { ...data, content: '', wordCount: 0, emptyReason: 'idstack could not read the text of this Google Doc. If downloading is turned off for it, consider asking the owner to allow downloads.' };
  }
}

// Injected with chrome.scripting.executeScript({ files }): the value of the final
// statement is the InjectionResult the side panel reads, so extractPageContent()
// must stay last. Re-injected on every refresh into the same isolated world, so no
// top-level let/const/class (redeclaring them throws).
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    detectPageType,
    extractContentFromDOM,
    extractPageContent
  };
} else {
  extractPageContent();
}
