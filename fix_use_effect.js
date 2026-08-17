const fs = require('fs');
const content = fs.readFileSync('web_portal/src/app/teacher/(main)/courses/[id]/page.tsx', 'utf8');

// We need to clean up the duplicated onAuthStateChanged.
// Let's just find the entire useEffect block and replace it.

const start = content.indexOf('useEffect(() => {');
const end = content.indexOf('  }, [courseId, router]);') + '  }, [courseId, router]);'.length;

const cleanBlock = `  useEffect(() => {
    let userUnsub: any = null;
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      try {
        const courseRef = doc(db, "courses", courseId);
        const courseSnap = await getDoc(courseRef);
        
        if (!courseSnap.exists()) {
          router.push("/teacher/courses");
          return;
        }

        const data = courseSnap.data();
        if (data.teacherId !== user.uid) {
          router.push("/teacher/courses");
          return;
        }

        const userRef = doc(db, "users", user.uid);
        userUnsub = onSnapshot(userRef, (userSnap) => {
          if (userSnap.exists()) {
            const uData = userSnap.data();
            if (uData.commissionRate !== undefined) {
              setTeacherCommission(uData.commissionRate * 100);
            } else if (uData.earningPercentage !== undefined) {
              setTeacherCommission(uData.earningPercentage);
            } else {
              setTeacherCommission(null);
            }
          } else {
            setTeacherCommission(null);
          }
        });

        setCourse({ id: courseSnap.id, ...data });

        // Fetch assignments for this course
        const assignSnap = await getDocs(collection(db, "courses", courseId, "assignments"));
        const assignList = await Promise.all(assignSnap.docs.map(async (d) => {
          const subsSnap = await getDocs(collection(db, "courses", courseId, "assignments", d.id, "submissions"));
          return {
            id: d.id,
            ...d.data(),
            submissionCount: subsSnap.size
          };
        }));
        setAssignments(assignList);

      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    });
    return () => {
      unsub();
      if (userUnsub) userUnsub();
    };
  }, [courseId, router]);`;

const newContent = content.substring(0, start) + cleanBlock + content.substring(end);
fs.writeFileSync('web_portal/src/app/teacher/(main)/courses/[id]/page.tsx', newContent);
console.log("Fixed!");
