const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

const brevoApiKey = defineSecret("BREVO_API_KEY");

console.log("[NotificationModule] Initialized");

// Helper: Get localized text
function getLocalizedText(lang, key, params = {}) {
    const dictionary = {
        en: {
            new_enrollment_title: "New Student Enrolled! 🎓",
            new_enrollment_body: "{studentName} just joined '{courseName}'.",
            new_comment_title: "New Comment 💬",
            new_comment_body: "{userName} commented on your post.",
            new_like_title: "New Like ❤️",
            new_like_body: "Someone liked your post.",
            new_submission_title: "New Assignment Submission 📄",
            new_submission_body: "A student submitted work for '{assignmentTitle}'.",
            account_approved_title: "Account Approved! ✨",
            account_approved_body: "Welcome to Calligro, {name}! Your teacher account is now active.",
            account_approved_email_subject: "Your Calligro Teacher Account is Approved! 🎓",
            account_approved_email_body: "Thank you for being a part of Calligro! Your teacher account has been approved. You can now log in to the app and start creating your courses.\n\nWe are excited to have you with us!",
            account_rejected_title: "Application Update 📢",
            account_rejected_body: "We have reviewed your teacher application. Tap to see the details.",
            account_rejected_email_subject: "Update regarding your Calligro Teacher Application 📄",
            account_rejected_email_body: "Thank you for your interest in joining Calligro. After reviewing your profile and portfolio, we have decided not to move forward with your teacher account at this time.\n\nYou can log in to the app to see more details and manage your account data.",
            new_follower_title: "New Follower! 👤",
            new_follower_body: "{followerName} started following you.",
        },
        ar: {
            new_enrollment_title: "طالب جديد مسجل! 🎓",
            new_enrollment_body: "انضم {studentName} للتو إلى '{courseName}'.",
            new_comment_title: "تعليق جديد 💬",
            new_comment_body: "علق {userName} على منشورك.",
            new_like_title: "إعجاب جديد ❤️",
            new_like_body: "أعجب شخص ما بمنشورك.",
            new_submission_title: "تسليم واجب جديد 📄",
            new_submission_body: "قام طالب بتسليم عمل لـ '{assignmentTitle}'.",
            account_approved_title: "تم الموافقة على الحساب! ✨",
            account_approved_body: "مرحباً بك في كاليجرو، {name}! حسابك كمعلم مفعل الآن.",
            account_approved_email_subject: "تم تفعيل حسابك كمعلم في كاليجرو! 🎓",
            account_approved_email_body: "شكراً لانضمامك إلى كاليجرو! تم تفعيل حسابك كمعلم بنجاح. يمكنك الآن تسجيل الدخول والبدء في إنشاء دوراتك التدريبية.\n\nنحن سعداء بوجودك معنا!",
            account_rejected_title: "تحديث بخصوص طلبك 📢",
            account_rejected_body: "لقد قمنا بمراجعة طلب المعلم الخاص بك. اضغط لرؤية التفاصيل.",
            account_rejected_email_subject: "تحديث بخصوص طلب المعلم في كاليجرو 📄",
            account_rejected_email_body: "نشكرك على اهتمامك بالانضمام إلى كاليجرو. بعد مراجعة ملفك الشخصي وأعمالك، قررنا عدم المتابعة في تفعيل حساب المعلم الخاص بك في الوقت الحالي.\n\nيمكنك تسجيل الدخول إلى التطبيق لرؤية المزيد من التفاصيل وإدارة بيانات حسابك.",
            new_follower_title: "متابع جديد! 👤",
            new_follower_body: "بدأ {followerName} بمتابعتك.",
        },
        tr: {
            new_enrollment_title: "Yeni Öğrenci Kaydoldu! 🎓",
            new_enrollment_body: "{studentName} az önce '{courseName}' kursuna katıldı.",
            new_comment_title: "Yeni Yorum 💬",
            new_comment_body: "{userName} gönderine yorum yaptı.",
            new_like_title: "Yeni Beğeni ❤️",
            new_like_body: "Biri gönderinizi beğendi.",
            new_submission_title: "Yeni Ödev Teslimi 📄",
            new_submission_body: "Bir öğrenci '{assignmentTitle}' için ödev teslim etti.",
            account_approved_title: "Hesap Onaylandı! ✨",
            account_approved_body: "Calligro'ya hoş geldiniz, {name}! Eğitmen hesabınız artık aktif.",
            account_approved_email_subject: "Calligro Eğitmen Hesabınız Onaylandı! 🎓",
            account_approved_email_body: "Calligro'nun bir parçası olduğunuz için teşekkür ederiz! Eğitmen hesabınız onaylandı. Artık uygulamaya giriş yapabillir ve kurslarınızı oluşturmaya başlayabilirsiniz.\n\nSizi aramızda görmekten mutluluk duyuyoruz!",
            account_rejected_title: "Başvuru Güncellemesi 📢",
            account_rejected_body: "Eğitmen başvurunuzu inceledik. Detayları görmek için dokunun.",
            account_rejected_email_subject: "Calligro Eğitmen Başvurunuz Hakkında Güncelleme 📄",
            account_rejected_email_body: "Calligro'ya katılmaya gösterdiğiniz ilgi için teşekkür ederiz. Profiliniz ve portfolyonuz incelendikten sonra, şu aşamada eğitmen hesabınızla devam etmeme kararı aldık.\n\nDaha fazla ayrıntı görmek ve hesap verilerinizi yönetmek için uygulamaya giriş yapabilirsiniz.",
            new_follower_title: "Yeni Takipçi! 👤",
            new_follower_body: "{followerName} seni takip etmeye başladı.",
        },
    };

    const htmlTemplates = {
        en: {
            header: "Welcome to Calligro",
            greeting: "Hello {name},",
            footer: "&copy; 2026 Calligro Team. All rights reserved.",
        },
        ar: {
            header: "مرحباً بك في كاليجرو",
            greeting: "مرحباً {name}،",
            footer: "&copy; 2026 فريق كاليجرو. جميع الحقوق محفوظة.",
        },
        tr: {
            header: "Calligro'ya Hoş Geldiniz",
            greeting: "Merhaba {name},",
            footer: "&copy; 2026 Calligro Ekibi. Tüm hakları saklıdır.",
        }
    };

    const safeLang = dictionary[lang] ? lang : "en";

    if (key.startsWith("html_")) {
        const templateType = key.replace("html_", ""); // e.g., "account_approved" or "account_rejected"
        const t = htmlTemplates[safeLang];
        const bodyText = dictionary[safeLang][`${templateType}_email_body`].replace("{name}", params.name);

        return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f9f9f9; margin: 0; padding: 0; direction: ${safeLang === 'ar' ? 'rtl' : 'ltr'}; }
    .container { max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.05); }
    .header { background: linear-gradient(135deg, #FFD700 0%, #FFA000 100%); padding: 40px 20px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 28px; font-weight: 700; text-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .content { padding: 40px; color: #444444; line-height: 1.6; font-size: 16px; }
    .greeting { font-size: 20px; font-weight: 600; color: #222222; margin-bottom: 20px; }
    .body-text { margin-bottom: 30px; }
    .button-container { text-align: center; margin: 40px 0; }
    .button { background-color: #FFD700; color: #000000; padding: 16px 32px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 16px; display: inline-block; transition: background-color 0.3s ease; }
    .footer { background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 12px; color: #888888; border-top: 1px solid #eeeeee; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Calligro</h1>
    </div>
    <div class="content">
      <div class="greeting">${t.greeting.replace("{name}", params.name)}</div>
      <div class="body-text">
        ${bodyText}
      </div>
      <div class="button-container">
        <a href="https://calligro.digital" class="button">${t.header}</a>
      </div>
    </div>
    <div class="footer">
      <p>${t.footer}</p>
    </div>
  </div>
</body>
</html>
        `;
    }

    let text = dictionary[safeLang][key] || dictionary["en"][key];

    for (const [pKey, pVal] of Object.entries(params)) {
        text = text.replace(`{${pKey}}`, pVal);
    }
    return text;
}

// Helper: Send Notification
async function sendNotification({ receiverId, type, titleKey, bodyKey, params = {}, payload = {} }) {
    try {
        console.log(`[Notification] Attempting to notify ${receiverId} (Type: ${type})`);
        const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const token = userData.fcmToken;
        const lang = userData.preferredLanguage || "en";

        const title = getLocalizedText(lang, titleKey, params);
        const body = getLocalizedText(lang, bodyKey, params);

        // 1. Save to in-app inbox
        await admin.firestore().collection("users").doc(receiverId).collection("notifications").add({
            title,
            body,
            type,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 2. Send Push Notification
        if (token) {
            console.log(`[Notification] Sending FCM to token ending in ...${token.slice(-5)}`);
            await admin.messaging().send({
                token,
                notification: {
                    title,
                    body,
                },
                data: {
                    type,
                    title,
                    body,
                    ...payload
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "calligro_alerts",
                    }
                },
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title,
                                body
                            },
                            sound: "default",
                        }
                    }
                }
            });
            console.log(`[Notification] FCM sent successfully to ${receiverId}`);
        } else {
            console.warn(`[Notification] No FCM token found for user ${receiverId}`);
        }
    } catch (err) {
        console.error("sendNotification error:", err);
    }
}

// Helper: Send Email via Brevo (using raw fetch for better reliability)
async function sendEmail({ email, subjectKey, bodyKey, params = {}, lang = "en" }) {
    try {
        const apiKey = brevoApiKey.value();
        if (!apiKey) {
            console.error("[Email] Critical: BREVO_API_KEY is missing or empty.");
            return;
        }

        console.log(`[Email] Sending to ${email} (Lang: ${lang})`);

        const subject = getLocalizedText(lang, subjectKey, params);
        const htmlContent = getLocalizedText(lang, `html_${bodyKey.replace("_email_body", "")}`, params);

        const response = await fetch("https://api.brevo.com/v3/smtp/email", {
            method: "POST",
            headers: {
                "accept": "application/json",
                "api-key": apiKey,
                "content-type": "application/json",
            },
            body: JSON.stringify({
                sender: { email: "no-reply@calligro.digital", name: "Calligro Team" },
                to: [{ email }],
                subject: subject,
                htmlContent: htmlContent,
            }),
        });

        const result = await response.json();
        if (response.ok) {
            console.log(`[Email] Success! Message ID: ${result.messageId}`);
        } else {
            console.error(`[Email] API Error (${response.status}):`, JSON.stringify(result));
        }
    } catch (err) {
        console.error("[Email] Request failed:", err.message);
    }
}

// ------------------------------------------------------------------------
// Trigger 1: New Student Enrollment (Notifies Teacher)
// ------------------------------------------------------------------------
exports.notifyTeacherOnEnrollment = onDocumentUpdated("courses/{courseId}", async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    const oldStudents = beforeData.enrolledStudents || [];
    const newStudents = afterData.enrolledStudents || [];

    if (newStudents.length <= oldStudents.length) return null;

    const newStudentId = newStudents.find(id => !oldStudents.includes(id));
    if (!newStudentId) return null;

    const teacherId = afterData.teacherId;
    if (!teacherId) return null;

    // Get student name
    const studentDoc = await admin.firestore().collection("users").doc(newStudentId).get();
    const studentName = studentDoc.exists ? (studentDoc.data().name || "A student") : "A student";

    await sendNotification({
        receiverId: teacherId,
        type: "enrollment",
        titleKey: "new_enrollment_title",
        bodyKey: "new_enrollment_body",
        params: { studentName, courseName: afterData.title || "your course" }
    });
});

// ------------------------------------------------------------------------
// Trigger 2: New Community Comment (Notifies Post Author)
// ------------------------------------------------------------------------
exports.notifyAuthorOnComment = onDocumentCreated("community_posts/{postId}/comments/{commentId}", async (event) => {
    const commentData = event.data.data();
    if (!commentData) return null;

    // Get post to find the author
    const postDoc = await admin.firestore().collection("community_posts").doc(event.params.postId).get();
    if (!postDoc.exists) return null;

    const postAuthorId = postDoc.data().userId;
    // Don't notify if they comment on their own post
    if (postAuthorId === commentData.userId) return null;

    // Check user preferences
    const authorDoc = await admin.firestore().collection("users").doc(postAuthorId).get();
    if (!authorDoc.exists) return null;
    const authorData = authorDoc.data();
    if (authorData.wantsSocialNotifications === false) {
        console.log(`[Notification] User ${postAuthorId} muted social notifications. Skipping comment push.`);
        return null;
    }

    await sendNotification({
        receiverId: postAuthorId,
        type: "comment",
        titleKey: "new_comment_title",
        bodyKey: "new_comment_body",
        params: { userName: commentData.userName || "Someone" },
        payload: {
            route: '/postDetails',
            postId: event.params.postId
        }
    });
});

// ------------------------------------------------------------------------
// Trigger 2.5: New Community Like (Notifies Post Author)
// ------------------------------------------------------------------------
exports.notifyAuthorOnLike = onDocumentUpdated("community_posts/{postId}", async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // Check if likes object exists
    const beforeLikes = beforeData.likes || {};
    const afterLikes = afterData.likes || {};

    // Find if a new like was added
    const newLikerIds = Object.keys(afterLikes).filter(id => !beforeLikes[id]);

    // If no new likes, exit
    if (newLikerIds.length === 0) return null;

    const postAuthorId = afterData.userId;
    const newLikerId = newLikerIds[0]; // Just take the first one if multiple happened simultaneously

    // Don't notify if they like their own post
    if (postAuthorId === newLikerId) return null;

    // Check user preferences
    const authorDoc = await admin.firestore().collection("users").doc(postAuthorId).get();
    if (!authorDoc.exists) return null;
    const authorData = authorDoc.data();
    if (authorData.wantsSocialNotifications === false) {
        console.log(`[Notification] User ${postAuthorId} muted social notifications. Skipping like push.`);
        return null;
    }

    await sendNotification({
        receiverId: postAuthorId,
        type: "like",
        titleKey: "new_like_title",
        bodyKey: "new_like_body",
        payload: {
            route: '/postDetails',
            postId: event.params.postId
        }
    });
});

// ------------------------------------------------------------------------
// Trigger 3: New Assignment Submission (Notifies Teacher)
// ------------------------------------------------------------------------
exports.notifyTeacherOnSubmission = onDocumentCreated("courses/{courseId}/assignments/{assignmentId}/submissions/{submissionId}", async (event) => {
    const submissionData = event.data.data();
    if (!submissionData) return null;

    // Get course to find teacher
    const courseDoc = await admin.firestore().collection("courses").doc(event.params.courseId).get();
    if (!courseDoc.exists) return null;
    const teacherId = courseDoc.data().teacherId;

    // Get assignment to find title
    const assignmentDoc = await admin.firestore()
        .collection("courses").doc(event.params.courseId)
        .collection("assignments").doc(event.params.assignmentId).get();

    const assignmentTitle = assignmentDoc.exists ? (assignmentDoc.data().title || "Assignment") : "Assignment";

    await sendNotification({
        receiverId: teacherId,
        type: "assignment",
        titleKey: "new_submission_title",
        bodyKey: "new_submission_body",
        params: { assignmentTitle }
    });
});

// ------------------------------------------------------------------------
// Trigger 4: Teacher Account Approval (Notifies Teacher)
// ------------------------------------------------------------------------
exports.notifyTeacherOnApproval = onDocumentUpdated({
    document: "users/{uid}",
    secrets: [brevoApiKey]
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    console.log(`[ApprovalCheck] User ${event.params.uid} status: ${beforeData.status} -> ${afterData.status}, role: ${afterData.role}`);

    // Check if status changed from 'pending' to 'approved'
    if (beforeData.status === "pending" && afterData.status === "approved" && afterData.role === "teacher") {
        console.log(`[ApprovalCheck] Condition met for ${event.params.uid}. Sending notifications...`);

        // 1. Send Push Notification & In-App notification
        await sendNotification({
            receiverId: event.params.uid,
            type: "account_status",
            titleKey: "account_approved_title",
            bodyKey: "account_approved_body",
            params: { name: afterData.name || "Teacher" }
        });

        // 2. Send Email Notification
        if (afterData.email) {
            await sendEmail({
                email: afterData.email,
                subjectKey: "account_approved_email_subject",
                bodyKey: "account_approved_email_body",
                params: { name: afterData.name || "Teacher" },
                lang: afterData.preferredLanguage || "en"
            });
        } else {
            console.warn(`[ApprovalCheck] Skipping email for ${event.params.uid} because email field is missing.`);
        }
    }

    // Check if status changed from 'pending' to 'rejected'
    if (beforeData.status === "pending" && afterData.status === "rejected" && afterData.role === "teacher") {
        console.log(`[RejectionCheck] Condition met for ${event.params.uid}. Sending notifications...`);

        // 1. Send Push Notification & In-App notification
        await sendNotification({
            receiverId: event.params.uid,
            type: "account_status",
            titleKey: "account_rejected_title",
            bodyKey: "account_rejected_body",
            params: { name: afterData.name || "Teacher" }
        });

        // 2. Send Email Notification
        if (afterData.email) {
            await sendEmail({
                email: afterData.email,
                subjectKey: "account_rejected_email_subject",
                bodyKey: "account_rejected_email_body",
                params: { name: afterData.name || "Teacher" },
                lang: afterData.preferredLanguage || "en"
            });
        }
    }
    return null;
});

// [REMOVED] notifyUserOnDirectMessage was causing an infinite loop because it triggered on the same collection it wrote to.
// All direct notifications should now be handled directly by calling sendNotification() from the source service.

// ------------------------------------------------------------------------
// Trigger 6: Admin Broadcast Message
// ------------------------------------------------------------------------
exports.notifyUsersOnBroadcast = onDocumentCreated("broadcasts/{broadcastId}", async (event) => {
    const broadcastData = event.data.data();
    if (!broadcastData) return null;

    const title = broadcastData.title || "Announcement";
    const body = broadcastData.message || "";
    // Accept 'all', 'teacher', 'student' (or 'teachers' / 'students' from UI)
    const audienceStr = (broadcastData.targetAudience || "all").toLowerCase();

    let audienceFilter = null;
    if (audienceStr.includes('teacher')) {
        audienceFilter = 'teacher';
    } else if (audienceStr.includes('student')) {
        audienceFilter = 'student';
    }

    try {
        console.log(`[Broadcast] Starting broadcast to audience: ${audienceStr} (${audienceFilter || 'all'})`);

        // 1. Fetch Users
        let usersQuery = admin.firestore().collection("users");
        if (audienceFilter) {
            usersQuery = usersQuery.where("role", "==", audienceFilter);
        }
        const usersSnapshot = await usersQuery.get();

        const tokens = [];
        const userIds = [];

        usersSnapshot.forEach(doc => {
            const data = doc.data();
            userIds.push(doc.id);
            if (data.fcmToken) {
                // Ensure unique tokens
                if (!tokens.includes(data.fcmToken)) {
                    tokens.push(data.fcmToken);
                }
            }
        });

        console.log(`[Broadcast] Found ${userIds.length} users, ${tokens.length} FCM tokens.`);

        if (tokens.length === 0) {
            console.log("[Broadcast] No tokens to send to. Aborting.");
            return null;
        }

        // 2. Send Push Notifications (Batches of 500 max per Firebase limits)
        const payload = {
            notification: {
                title,
                body,
            },
            data: {
                type: "broadcast",
                title,
                body
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "calligro_alerts",
                }
            },
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title,
                            body
                        },
                        sound: "default",
                    }
                }
            }
        };

        // Firebase limit for sendEachForMulticast is 500
        const batchSize = 500;
        let successCount = 0;
        let failureCount = 0;

        for (let i = 0; i < tokens.length; i += batchSize) {
            const tokensBatch = tokens.slice(i, i + batchSize);
            const response = await admin.messaging().sendEachForMulticast({
                tokens: tokensBatch,
                ...payload
            });
            successCount += response.successCount;
            failureCount += response.failureCount;

            if (response.failureCount > 0) {
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        console.warn(`[Broadcast] Failure for token: ${tokensBatch[idx]}, error: ${resp.error}`);
                    }
                });
            }
        }

        console.log(`[Broadcast] Done. Sent ${successCount} messages. Failed: ${failureCount}`);

        // 3. Mark broadcast as processed
        await event.data.ref.update({
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            recipientsCount: userIds.length,
            successCount: successCount
        });

    } catch (err) {
        console.error("notifyUsersOnBroadcast error:", err);
    }

    return null;
});

// [REMOVED] notifyUserOnFollow was causing a critical infinite loop (8.4M invocations).
// It triggered on a new notification document and then called sendNotification, which added another document to the same collection.
// Follow notifications are now handled directly in the follow/unfollow logic in the app or a dedicated non-circular trigger.
