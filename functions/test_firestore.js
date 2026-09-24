const admin = require("firebase-admin");

const privateKey = "-----BEGIN PRIVATE KEY-----\n" +
"MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDc5yMSRdtxC2RV\n" +
"IfvnCqTehyGheVqT3XDqTLe6IMTOn2l97a/6H1BkvgOo9isFzX8/7eg5rkWj8ydR\n" +
"MWFHArpHKJxByG26dU5ruJ3wGEzqmuZqLS4VFBN1XnRR5coVdj1ibs96O4HWnhvO\n" +
"OrMjo5LYkG7pD6AxdeN1PvuaR7+NCEfsQlnf6LRBXPrWlRCuT9BNJKuSGJfty6S7\n" +
"k2qMpZuWkTSK6i6iyWEWcndqg0/THAXKLJrMqv/jQ+3XClm8cPOOjpqQYZy/cGqZ\n" +
"1z1DiMjvQQRS27tdiLsCOw5QghC0fy/gM3ecTpDVTjEqLCfMi9utICmLSpPAms58\n" +
"bEFBSCJdAgMBAAECgf8QZRc1Q/oFadMIfn0zqJaT7XORiHAwiT7YJNl99vCkZTBv\n" +
"KDTnW2ucDn43DA4lYBsRo5aYsVZ51JIWdJPDsXAh1+HBAB8kt5AabplKOIN85gIz\n" +
"3yaMafEHxPrdGTDmZuAnbhH4AHKiexmVNMYW3w0HBbE1mvNIuHcpPINv7+NHlDJr\n" +
"rLkwoiyadSM59Fch4VtmZ76WdFLA59lsaAQY7D2w1wLwIpd+Pu83xD4mRGuUIcsN\n" +
"8kd4lr8Yk1cgqYA0IEJw0qVwjGjMOFmiGY6s1sEx/cOz/b3X31ln/x68p48AhemF\n" +
"zTUf+siDY6kcj3XNZcqCtO99byPTW+siDY6kcj3XNZcqCtO99byPTW+iv+G5qP6E\n" +
"CgYEA+U4iR+Ddgm+i6z1RmsJwTn3SeIx6jG8jdF5e9Y9tgrYi3DgMXaI2GXjCNTK\n" +
"w0fSy+tlhsmOgJGz/8yTIh4SSa5MRgIaUr6Jdei2pwBVYoui9XskYZwLOu7WMH1h\n" +
"yK/VrzP9SjDwYDhy8m969MySBHBxv8Tzg/TLkzWl5xcBxhQUCgYEA4tW/0HN/jPG\n" +
"impgF7gPY6dKGJaSfPpaFHnS1RcgmEJv5F/KTT0YhuqG3hrev3kLCWUUkul1YxML\n" +
"E1kZvP9EbqMR77hSmiiIQ8mYdcr0PaO79c8LzO6NLnTqM5RYL6V+owJPkjgzZbpt\n" +
"L32NnQJx8BCuqNae/aqHvebZBa2Sp3kCgYEAtLT+BDvqU/G3lewMirEF1t89AERT\n" +
"UBf/CwqcqkIcjvKWsimuTPCXZj8yBn2HzaghU9LeDgBIxB5+KDAxaomd2Hvx48ep\n" +
"XuXB/B29PY47gVSabI6DfDrCQS/XLkviM2MJjusChpFFXWfARyi578+FrJGMgZ+z\n" +
"wlk77/UlJK5tkECgYEAjs7bkDTm3KlUIdgMA6lQawUrh4944kKJVH9NkL1Nma9Yx\n" +
"4bkz0fr/D/L93i1tEx7ZxBs6xfRxy6IFg8KAzd3Hm11SJKftt9zo+g+Kfp1NS8hS\n" +
"jw2Phm0hSxTf/a9URP0fimd/wB/8265+c3vN3JNcaK76kPN8yg4SHxCLM/mQKECg\n" +
"YEAy1EP3LdZ+eb2kuwzJ+Rj/bvq+iRiqIXuz7krld2Yr1P7LSx3wm7mqQEU9oTML\n" +
"D6tg5fTz3+3/Juy2R4++xkiLI8fyY71ykKjNRyDMsolV1x+1xaGZFQvyAYmu1zjp\n" +
"eFCLS5eNAHcqq5SbGUShL2qjO030LSFlIOGWdx4BVSCzh0=\n" +
"-----END PRIVATE KEY-----\n";

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: "calligro-bcfb2",
      clientEmail: "firebase-adminsdk-fbsvc@calligro-bcfb2.iam.gserviceaccount.com",
      privateKey: privateKey
    })
  });
}

async function check() {
  const doc = await admin.firestore().collection("courses").doc("oZ5sesftxFHQ1F1gwBYB").get();
  console.log(JSON.stringify(doc.data().curriculum, null, 2));
}

check().catch(console.error);
