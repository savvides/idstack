function stripHtml(html) {
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

async function crawlCanvasCourse(origin, courseId) {
  if (!origin || !courseId) {
    throw new Error('Canvas origin and courseId are required for course crawling.');
  }

  // 1. Fetch Course details & syllabus
  const courseUrl = `${origin}/api/v1/courses/${courseId}?include[]=syllabus_body`;
  const courseRes = await fetch(courseUrl, { credentials: 'include' });
  if (!courseRes.ok) {
    throw new Error(`Failed to fetch Canvas course info (${courseRes.status})`);
  }
  const courseJson = await courseRes.json();

  // 2. Fetch Assignments list (up to 50)
  const assignmentsUrl = `${origin}/api/v1/courses/${courseId}/assignments?per_page=50`;
  let assignments = [];
  try {
    const assignRes = await fetch(assignmentsUrl, { credentials: 'include' });
    if (assignRes.ok) {
      const assignJson = await assignRes.json();
      if (Array.isArray(assignJson)) {
        assignments = assignJson.map((a) => ({
          title: a.name || 'Untitled Assignment',
          description: stripHtml(a.description || '').slice(0, 1000),
          points: a.points_possible || 0,
          dueAt: a.due_at || null
        }));
      }
    }
  } catch (e) {
    console.warn('Could not fetch assignments list:', e);
  }

  return {
    title: courseJson.name || courseJson.course_code || 'Canvas Course',
    syllabus: stripHtml(courseJson.syllabus_body || ''),
    assignments
  };
}

module.exports = {
  stripHtml,
  crawlCanvasCourse
};
