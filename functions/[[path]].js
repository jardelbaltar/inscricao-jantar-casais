const SUPABASE_URL = "https://nuqcefxwarrjehvhdoug.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51cWNlZnh3YXJyamVodmhkb3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3NzE1NzUsImV4cCI6MjA4NjM0NzU3NX0.xLugRmdl6UKVsMZnDepBlFndh4vGVMnptuloFZC28Mc";

const escapeHtml = (value) => String(value).replace(/[&<>"]/g, (char) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;"
}[char]));

async function getEventTitle(eventSlug) {
  if (!eventSlug) return null;

  const url = new URL("/rest/v1/events", SUPABASE_URL);
  url.searchParams.set("select", "title");
  url.searchParams.set("slug", `eq.${eventSlug}`);
  url.searchParams.set("limit", "1");

  const response = await fetch(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`
    }
  });

  if (!response.ok) return null;

  const [event] = await response.json();
  return event?.title?.trim() || null;
}

function replaceMeta(html, title) {
  const safeEventTitle = escapeHtml(title);
  const safePageTitle = `Inscrição - ${safeEventTitle}`;
  const safeDescription = `Faça sua inscrição para ${safeEventTitle}.`;

  return html
    .replace(/<title>.*?<\/title>/i, `<title>${safePageTitle}</title>`)
    .replace(/<meta name="description" content=".*?" \/>/i, `<meta name="description" content="${safeDescription}" />`)
    .replace(/<meta property="og:title" content=".*?" \/>/i, `<meta property="og:title" content="${safePageTitle}" />`)
    .replace(/<meta property="og:description" content=".*?" \/>/i, `<meta property="og:description" content="${safeDescription}" />`)
    .replace(/<meta name="twitter:title" content=".*?" \/>/i, `<meta name="twitter:title" content="${safePageTitle}" />`)
    .replace(/<meta name="twitter:description" content=".*?" \/>/i, `<meta name="twitter:description" content="${safeDescription}" />`);
}

export async function onRequestGet({ request, env }) {
  const url = new URL(request.url);
  const isRegistrationPage = url.pathname === "/" || url.pathname === "/index.html";

  const assetResponse = await env.ASSETS.fetch(request);
  if (!isRegistrationPage || !assetResponse.ok) return assetResponse;

  const eventTitle = await getEventTitle(url.searchParams.get("event")?.trim());
  if (!eventTitle) return assetResponse;

  const html = await assetResponse.text();
  return new Response(replaceMeta(html, eventTitle), {
    status: assetResponse.status,
    headers: {
      ...Object.fromEntries(assetResponse.headers),
      "content-type": "text/html; charset=utf-8"
    }
  });
}
