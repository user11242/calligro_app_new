export function formatImageUrl(url?: string) {
  if (!url) return undefined;
  if (url.startsWith('assets/')) {
    return `/${url}`;
  }
  return url;
}
