const fs = require('fs');
let code = fs.readFileSync('web_portal/src/app/courses/page.tsx', 'utf8');

// Replace the hardcoded style inside motion.div
// Also pass bentoClass from the map directly into the motion.div's className

const replaceTarget = `              {filteredCourses.map((course, idx) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, scale: 0.95, y: 40 }}
                  animate={{ opacity: 1, scale: 1, y: 0 }}
                  transition={{ delay: idx * 0.1, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
                  className={/* wrapper gets the column span from BentoCourse via child but we must apply to motion.div */ ""}
                  style={{ gridColumn: (idx % 4 === 0) ? 'span 7' : (idx % 4 === 1 || idx % 4 === 2) ? 'span 5' : 'span 7' }}
                  // Wait, actually I shouldn't pass style gridColumn here. I will just let BentoCourse return it, but motion.div wraps it.
                  // Instead of motion.div wrapping, I'll pass className via props or just do standard layout
                >
                  <BentoCourse course={course} index={idx} currentUser={currentUser} locale={locale} />
                </motion.div>
              ))}`;

const replacement = `              {filteredCourses.map((course, idx) => {
                let bentoClass = "bento-card-small";
                if (idx % 4 === 0) bentoClass = "bento-card-large";
                else if (idx % 4 === 1 || idx % 4 === 2) bentoClass = "bento-card-medium";
                else bentoClass = "bento-card-large"; // Using large to complete the 12 columns grid

                return (
                  <motion.div
                    key={course.id}
                    initial={{ opacity: 0, scale: 0.95, y: 40 }}
                    animate={{ opacity: 1, scale: 1, y: 0 }}
                    transition={{ delay: idx * 0.1, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
                    className={bentoClass}
                  >
                    <BentoCourse course={course} index={idx} currentUser={currentUser} locale={locale} />
                  </motion.div>
                );
              })}`;

code = code.replace(replaceTarget, replacement);
fs.writeFileSync('web_portal/src/app/courses/page.tsx', code);
console.log("Fixed Grid CSS");
