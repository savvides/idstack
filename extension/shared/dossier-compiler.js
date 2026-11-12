// Model text and page titles can hold newlines and |, which end a list item or
// split a table cell.
const oneLine = (v) => String(v).replace(/\r?\n/g, ' ');
const cell = (v) => oneLine(v).replace(/\|/g, '\\|');

export function compileSingleAuditToMarkdown(item) {
  if (!item || !item.result) return '';
  const result = item.result;
  const title = item.title || 'Course Material';
  const pageType = item.pageType || 'Web Page';
  const url = item.url || '';
  const timestamp = (item.timestamp ? new Date(item.timestamp) : new Date()).toLocaleString();

  let md = `# idstack Instructional Design Audit: ${title}\n\n`;
  md += `> **Audited Component:** ${pageType}  \n`;
  if (url) md += `> **Source URL:** [${url}](${url})  \n`;
  md += `> **Date:** ${timestamp}  \n`;
  md += `> **Evaluator:** idstack Evidence-Based Course Design Engine (Manifest V3)\n\n`;

  md += `## Executive Summary\n\n`;
  md += `- **Bloom's Demand:** ${result.summary?.bloomsLevel || 'N/A'}\n`;
  md += `- **Alignment Score:** ${result.summary?.alignmentScore || 'N/A'}\n`;
  md += `- **Key Takeaway:** ${oneLine(result.summary?.keyTakeaway || 'The audit has no summary.')}\n\n`;

  if (Array.isArray(result.findings) && result.findings.length > 0) {
    md += `## Findings, Evidence & Recommendations\n\n`;
    result.findings.forEach((f, idx) => {
      md += `### ${idx + 1}. [${f.tier || 'T1'}] ${f.citation || 'Citation'}\n\n`;
      md += `- **Severity:** \`${(f.severity || 'info').toUpperCase()}\`\n`;
      md += `- **Observation:** ${oneLine(f.observation || '')}\n`;
      md += `- **Evidence:** ${oneLine(f.evidence || '')}\n`;
      md += `- **Recommendation:** ${oneLine(f.recommendation || '')}\n\n`;
    });
  }

  if (result.improvedDraft && result.improvedDraft.content) {
    md += `## ${result.improvedDraft.title || 'Recommended Draft & Alignment Matrix'}\n\n`;
    md += `${result.improvedDraft.content}\n\n`;
  }

  md += `---\n*Made with [idstack](https://github.com/savvides/idstack) — Evidence-Based Course Design.*`;
  return md;
}

// The course label for a dossier comes from its items, not from the tab that is
// active when you export. Each item keeps the Canvas host and course ID of the
// page it audited and, for a full-course audit, the course name from Canvas.
// A course is its host and ID together: two hosts can each have a course 123.
export function dossierCourseLabel(dossierItems, fallback = 'Course Materials') {
  const items = (Array.isArray(dossierItems) ? dossierItems : []).filter((i) => i && i.courseId);
  const key = (i) => `${i.courseOrigin || ''}|${i.courseId}`;
  const keys = [...new Set(items.map(key))];
  if (keys.length > 1) return 'Several courses';
  if (keys.length === 1) {
    const titled = items.find((i) => i.courseTitle);
    return titled ? titled.courseTitle : `Course ${items[0].courseId}`;
  }
  return fallback;
}

export function compileDossierToMarkdown(dossierItems, courseTitle = 'Canvas Course') {
  if (!Array.isArray(dossierItems) || dossierItems.length === 0) {
    return `# idstack Course Audit Dossier: ${courseTitle}\n\n*The dossier has no audits.*`;
  }

  const timestamp = new Date().toLocaleString();
  let md = `# idstack Course Audit Dossier: ${courseTitle}\n\n`;
  md += `> **Course:** ${courseTitle}  \n`;
  md += `> **Total Audited Materials:** ${dossierItems.length} components  \n`;
  md += `> **Date:** ${timestamp}  \n`;
  md += `> **Engine:** idstack Evidence-Based Instructional Design Copilot\n\n`;

  md += `## Table of Audited Materials\n\n`;
  md += `| # | Component Title | Type | Bloom's Demand | Alignment Score |\n`;
  md += `| :--- | :--- | :--- | :--- | :--- |\n`;
  dossierItems.forEach((item, idx) => {
    const s = item.result?.summary || {};
    md += `| ${idx + 1} | ${cell(item.title || 'Untitled')} | ${cell(item.pageType || 'Page')} | ${cell(s.bloomsLevel || 'N/A')} | ${cell(s.alignmentScore || 'N/A')} |\n`;
  });
  md += `\n---\n\n`;

  dossierItems.forEach((item, idx) => {
    md += `## Section ${idx + 1}: ${item.title || 'Component'}\n\n`;
    md += `> **Type:** ${item.pageType || 'Page'} | **Source:** ${item.url || 'N/A'}\n\n`;

    const r = item.result || {};
    md += `### Summary\n`;
    md += `- **Bloom's Demand:** ${r.summary?.bloomsLevel || 'N/A'}\n`;
    md += `- **Alignment Score:** ${r.summary?.alignmentScore || 'N/A'}\n`;
    md += `- **Key Takeaway:** ${oneLine(r.summary?.keyTakeaway || 'N/A')}\n\n`;

    if (Array.isArray(r.findings) && r.findings.length > 0) {
      md += `### Findings & Evidence\n\n`;
      r.findings.forEach((f, fIdx) => {
        md += `#### ${idx + 1}.${fIdx + 1} [${f.tier || 'T1'}] ${f.citation || 'Citation'}\n`;
        md += `- **Observation:** ${oneLine(f.observation || '')}\n`;
        md += `- **Evidence:** ${oneLine(f.evidence || '')}\n`;
        md += `- **Recommendation:** ${oneLine(f.recommendation || '')}\n\n`;
      });
    }

    if (r.improvedDraft && r.improvedDraft.content) {
      md += `### ${r.improvedDraft.title || 'Recommended Draft'}\n\n`;
      md += `${r.improvedDraft.content}\n\n`;
    }

    md += `---\n\n`;
  });

  md += `*Made with [idstack](https://github.com/savvides/idstack) — Evidence-Based Course Design.*`;
  return md;
}
