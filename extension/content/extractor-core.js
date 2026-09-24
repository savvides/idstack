// Canvas course-root detection for the side panel. The content script does not use it.
export function detectCourseContext(url, docTitle) {
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

