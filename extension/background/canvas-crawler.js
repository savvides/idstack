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

export async function crawlCanvasCourse(origin, courseId, fetchImpl = fetch) {
  if (!origin || !courseId) {
    throw new Error('Canvas origin and courseId are required for course crawling.');
  }

  const courseUrl = `${origin}/api/v1/courses/${courseId}?include[]=syllabus_body`;
  const assignmentsUrl = `${origin}/api/v1/courses/${courseId}/assignments?per_page=50`;

  const coursePromise = fetchImpl(courseUrl, { credentials: 'include' }).then(async (res) => {
    if (!res.ok) {
      throw new Error(`Failed to fetch Canvas course info (${res.status})`);
    }
    return res.json();
  });

  const assignmentsPromise = fetchImpl(assignmentsUrl, { credentials: 'include' })
    .then(async (res) => {
      if (!res.ok) return [];
      const json = await res.json();
      if (!Array.isArray(json)) return [];
      return json.map((a) => ({
        title: a.name || 'Untitled Assignment',
        description: stripHtml(a.description || '').slice(0, 1000),
        points: a.points_possible || 0,
        dueAt: a.due_at || null
      }));
    })
    .catch((e) => {
      console.warn('Could not fetch assignments list:', e);
      return [];
    });

  const [courseJson, assignments] = await Promise.all([coursePromise, assignmentsPromise]);

  return {
    title: courseJson.name || courseJson.course_code || 'Canvas Course',
    syllabus: stripHtml(courseJson.syllabus_body || ''),
    assignments
  };
}
