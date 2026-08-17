const fs = require('fs');
let code = fs.readFileSync('web_portal/src/app/courses/page.tsx', 'utf8');

// The BentoCourse component currently does this:
//   let bentoClass = "bento-card-small";
//   if (index % 4 === 0) bentoClass = "bento-card-large";
//   ...
//   return (
//     <Link href={...} className={`bento-card group flex flex-col h-[400px] lg:h-auto ${bentoClass}`}>

// We need to change it to just `bento-card group flex flex-col h-[400px] lg:h-full` 
// and `isLarge` should just check if `index % 4 === 0 || index % 4 === 3`.

code = code.replace(
`  // Assign bento class based on index
  // Pattern: 0=Large(7), 1=Medium(5), 2=Medium(5), 3=Large(7), 4=Small(3)...
  let bentoClass = "bento-card-small";
  if (index % 4 === 0) bentoClass = "bento-card-large";
  else if (index % 4 === 1 || index % 4 === 2) bentoClass = "bento-card-medium";
  else bentoClass = "bento-card-small"; // for any remaining ones, or we can just alternate

  // Adjust aspect ratio based on size
  const isLarge = bentoClass === "bento-card-large";

  return (
    <Link href={isEnrolled ? \`/courses/\${course.id}/classroom\` : \`/courses/\${course.id}\`} className={\`bento-card group flex flex-col h-[400px] lg:h-auto \${bentoClass}\`}>`,
`  const isLarge = index % 4 === 0 || index % 4 === 3;

  return (
    <Link href={isEnrolled ? \`/courses/\${course.id}/classroom\` : \`/courses/\${course.id}\`} className="bento-card group flex flex-col h-[400px] lg:h-full w-full">`
);

fs.writeFileSync('web_portal/src/app/courses/page.tsx', code);
console.log("Fixed BentoCourse component CSS");
