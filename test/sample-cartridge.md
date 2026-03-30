# Testing /course-import with a Common Cartridge

## How to get a test .imscc file

### From Canvas
1. Open a course in Canvas
2. Go to Settings → Export Course Content
3. Select "Course" (full export)
4. Click "Create Export"
5. Download the .imscc file when ready

### From the IMS Global sample
The IMS Global Learning Consortium provides sample cartridge files:
- Search for "IMS Common Cartridge sample" on the IMS website
- These are minimal but valid cartridges for testing the parser

### From this repo's sample course
Use the scenario in test/sample-course.md as paste input for Path B testing.
The intentional quality gaps in the sample should trigger quality flags.

## Test protocol

1. Place the .imscc file in your working directory
2. Run `/course-import`
3. Choose option A (Common Cartridge)
4. Provide the file path
5. Verify:
   - Course structure extracted correctly (modules, items)
   - Quality flags fire (especially for courses with gaps)
   - Task analysis mapping is reasonable
   - Bloom's classification on any imported objectives
   - `.idstack/project.json` is valid JSON with populated fields
6. Run `/course-quality-review` and verify it reads the imported data
