/**
 * Injected content script to extract course content from Canvas, Google Docs, and web pages.
 */
function detectPageType(url, document) {
  if (url.includes('instructure.com') || url.includes('/courses/')) {
    if (document.querySelector('#assignment_show')) return 'Canvas Assignment';
    if (document.querySelector('#syllabusContainer') || url.includes('/assignments/syllabus')) return 'Canvas Syllabus';
    if (document.querySelector('#modules') || url.includes('/modules')) return 'Canvas Modules';
    if (document.querySelector('#rubrics')) return 'Canvas Rubric';
    return 'Canvas LMS Page';
  }
  if (url.includes('docs.google.com/document')) return 'Google Doc Syllabus';
  return 'Web Syllabus / Course Page';
}

function extractContentFromDOM(document, url = (typeof window !== 'undefined' && window.location ? window.location.href : '')) {
  const pageType = detectPageType(url, document);
  let title = (document && document.title) || 'Course Document';
  let content = '';

  if (pageType.startsWith('Canvas')) {
    const heading = document.querySelector('#assignment_show .title, .page-title, h1');
    if (heading) title = (heading.innerText || heading.textContent || '').trim();

    const mainBody = document.querySelector('#assignment_show .description.user_content, .show-content.user_content, #syllabusContainer, .module-item-title');
    content = mainBody ? (mainBody.innerText || mainBody.textContent || '').trim() : (document.body ? (document.body.innerText || document.body.textContent || '').trim() : '');
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
    wordCount: (content.match(/\S+/g) || []).length
  };
}

function extractPageContent() {
  const url = typeof window !== 'undefined' && window.location ? window.location.href : '';
  return extractContentFromDOM(document, url);
}

function detectCourseContext(url, docTitle) {
  if (!url) return { isCourseRoot: false, courseId: null, origin: null };
  try {
    const parsedUrl = new URL(url);
    const match = parsedUrl.pathname.match(/\/courses\/(\d+)(?:\/(?:modules)?)?\/?$/);
    const anyCourseMatch = parsedUrl.pathname.match(/\/courses\/(\d+)/);
    return {
      isCourseRoot: !!match,
      courseId: anyCourseMatch ? anyCourseMatch[1] : null,
      origin: parsedUrl.origin
    };
  } catch (e) {
    return { isCourseRoot: false, courseId: null, origin: null };
  }
}

// Listen for messages from Side Panel
if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'EXTRACT_CONTENT') {
      const data = extractPageContent();
      sendResponse(data);
    }
    return true;
  });
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    detectPageType,
    extractContentFromDOM,
    extractPageContent,
    detectCourseContext
  };
}
