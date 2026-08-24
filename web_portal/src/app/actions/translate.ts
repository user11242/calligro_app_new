"use server";

export async function translateText(text: string, targetLang: string = 'en'): Promise<string> {
  if (!text || text.trim() === '') return text;
  
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${targetLang}&dt=t&q=${encodeURIComponent(text)}`;
    const response = await fetch(url);
    const data = await response.json();
    
    let translated = '';
    if (data && data[0]) {
      for (const segment of data[0]) {
        if (segment[0]) {
          translated += segment[0];
        }
      }
      return translated;
    }
    return text;
  } catch (error) {
    console.error("Translation error:", error);
    return text;
  }
}
