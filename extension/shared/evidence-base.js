export const TIER_METADATA = {
  T1: { label: 'Meta-analysis', description: 'Systematic reviews / meta-analyses with large effect sizes', color: '#1d4e89' },
  T2: { label: 'Controlled trial', description: 'Peer-reviewed empirical randomized or quasi-experimental studies', color: '#007791' },
  T3: { label: 'Observational', description: 'Correlational, cohort, or longitudinal learning studies', color: '#588157' },
  T4: { label: 'Case study', description: 'Single-institution or discipline-specific qualitative studies', color: '#c97a22' },
  T5: { label: 'Expert guidance', description: 'Established instructional design frameworks (QM, OLC, Bloom)', color: '#6c757d' }
};

export const EVIDENCE_DOMAINS = [
  { code: 'Models', name: 'Instructional Design Models & Frameworks', keyStudies: ['Abuhassna et al. (2024) [T3]', 'Kalonde et al. (2025) [T3]', 'Crompton et al. (2023) [T3]'] },
  { code: 'Alignment', name: 'Constructive Alignment & Learning Objectives', keyStudies: ['Biggs (1996) [T5]', 'Anderson & Krathwohl (2001) [T5]', 'Agarwal (2019) [T1]'] },
  { code: 'Needs', name: 'Needs Analysis', keyStudies: ['Markaki et al. (2021) [T3]', 'Garavan et al. (2019) [T3]', 'Alsalamah & Callinan (2021) [T3]'] },
  { code: 'Cognitive', name: 'Cognitive Load Theory & Sequencing', keyStudies: ['Sweller (1994) [T5]', 'Costley et al. (2023) [T1]', 'Paas & van Merrienboer (2020) [T5]', 'Chen et al. (2018) [T1]'] },
  { code: 'Assessment', name: 'Formative Assessment & Feedback', keyStudies: ['Wisniewski et al. (2020) [T1]', 'Hattie & Timperley (2007) [T1]', 'Black & Wiliam (1998) [T1]', 'Double et al. (2019) [T1]'] },
  { code: 'Multimedia', name: 'Multimedia Learning Principles', keyStudies: ['Mayer (2024) [T5]', 'Moreno & Mayer (1999) [T1]', 'Noetel et al. (2021) [T1]'] },
  { code: 'Learner', name: 'Learner Analysis & Differentiation', keyStudies: ['Deunk et al. (2018) [T1]', 'Puzio et al. (2020) [T1]', 'Liou et al. (2023) [T2]'] },
  { code: 'Evaluation', name: 'Evaluation Models', keyStudies: ['Kirkpatrick / Alsalamah & Callinan (2021) [T3]', 'Frye & Hemmer (2012) [T5]', 'Allen et al. (2021) [T3]'] },
  { code: 'Prototype', name: 'Rapid Prototyping & Design-Based Research', keyStudies: ['Tripp & Bichelmeyer (1990) [T5]', 'Shakeel et al. (2022) [T2]', 'Design-Based Research Collective (2003) [T5]'] },
  { code: 'Online', name: 'Online Course Quality Frameworks', keyStudies: ['Quality Matters / Zimmerman et al. (2020) [T4]', 'Castro & Tumibay (2019) [T1]', 'Swan et al. (2012) [T2]'] },
  { code: 'Accessibility', name: 'Universal Design for Learning & A11y', keyStudies: ['CAST UDL Guidelines (2024) [T5]', 'WCAG 2.1/2.2 AA [T5]', 'Puzio et al. (2020) [T1]'] }
];
