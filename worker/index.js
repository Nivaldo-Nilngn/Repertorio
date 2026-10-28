import puppeteer from '@cloudflare/puppeteer';

export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': '*',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: corsHeaders,
      });
    }

    const url = new URL(request.url);
    const targetUrl = url.searchParams.get('url');

    if (!targetUrl) {
      return new Response(JSON.stringify({ error: 'Missing ?url= parameter' }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      });
    }

    // Try standard fetch first (fast path, works for BananaCifras and many other origins)
    try {
      const response = await fetch(targetUrl, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
          'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
          'sec-ch-ua':
            '"Chromium";v="130", "Google Chrome";v="130", "Not?A_Brand";v="99"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'document',
          'sec-fetch-mode': 'navigate',
          'sec-fetch-site': 'none',
          'sec-fetch-user': '?1',
          'upgrade-insecure-requests': '1',
        },
      });

      if (response.ok) {
        const body = await response.text();
        return new Response(body, {
          status: 200,
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            ...corsHeaders,
          },
        });
      }
    } catch (e) {
      console.log('Standard fetch failed, falling back to browser:', e.message);
    }

    // Fallback: Cloudflare Browser Rendering for sites protected by Akamai/Cloudflare WAF
    if (env.MYBROWSER) {
      let browser;
      try {
        browser = await puppeteer.launch(env.MYBROWSER);
        const page = await browser.newPage();
        await page.setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
        );

        // Abort non-essential media/font requests to load significantly faster
        await page.setRequestInterception(true);
        page.on('request', (req) => {
          const type = req.resourceType();
          if (['image', 'media', 'font', 'stylesheet'].includes(type)) {
            req.abort();
          } else {
            req.continue();
          }
        });

        await page.goto(targetUrl, {
          waitUntil: 'domcontentloaded',
          timeout: 20000,
        });

        // Wait up to 3s for chord content container to appear if available
        try {
          await page.waitForSelector('pre, .cifra_cnt', { timeout: 3000 });
        } catch (_) {}

        const content = await page.content();
        return new Response(content, {
          status: 200,
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            ...corsHeaders,
          },
        });
      } catch (browserErr) {
        return new Response(
          JSON.stringify({ error: `Browser rendering failed: ${browserErr.message}` }),
          {
            status: 500,
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders,
            },
          }
        );
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    }

    return new Response(
      JSON.stringify({ error: 'Failed to fetch page and browser rendering is not configured.' }),
      {
        status: 502,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      }
    );
  },
};
