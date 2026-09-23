export function stripHtml(html) {
  if (!html) return '';
  return html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

// 10 pages of 50 bounds the crawl at 500 assignments.
const MAX_ASSIGNMENT_PAGES = 10;

export async function crawlCanvasCourse(origin, courseId, fetchImpl = fetch) {
  if (!origin || !courseId) {
    throw new Error('Canvas origin and courseId are required for course crawling.');
  }

  // 1. Fetch Course details & syllabus
  const courseUrl = `${origin}/api/v1/courses/${courseId}?include[]=syllabus_body`;
  const courseRes = await fetchImpl(courseUrl, { credentials: 'include' });
  if (!courseRes.ok) {
    throw new Error(`Failed to fetch Canvas course info (${courseRes.status})`);
  }
  const courseJson = await courseRes.json();

  // 2. Fetch every page of the Assignments list (Canvas paginates via the Link
  // header). Any failure is fatal: an alignment audit run on a partial or empty
  // list tells the instructor the course has no assessments.
  const assignments = [];
  let assignmentsUrl = `${origin}/api/v1/courses/${courseId}/assignments?per_page=50`;
  for (let page = 1; assignmentsUrl; page++) {
    if (page > MAX_ASSIGNMENT_PAGES) {
      throw new Error(`This course has more than ${assignments.length} assignments, more than the full-course audit can read. Try auditing individual assignment pages instead.`);
    }
    const assignRes = await fetchImpl(assignmentsUrl, { credentials: 'include' });
    if (!assignRes.ok) {
      throw new Error(`Failed to fetch Canvas assignments (${assignRes.status})`);
    }
    const assignJson = await assignRes.json();
    assignments.push(...assignJson.map((a) => ({
      title: a.name || 'Untitled Assignment',
      description: stripHtml(a.description || '').slice(0, 1000),
      points: a.points_possible || 0,
      dueAt: a.due_at || null
    })));
    const next = /<([^>]+)>;\s*rel="next"/.exec(assignRes.headers.get('Link') || '');
    assignmentsUrl = next ? next[1] : null;
  }

  return {
    title: courseJson.name || courseJson.course_code || 'Canvas Course',
    syllabus: stripHtml(courseJson.syllabus_body || ''),
    assignments
  };
}
