require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'playwright'

Playwright.create(playwright_cli_executable_path: 'npx playwright') do |playwright|
  browser = playwright.chromium.launch(
    headless: true,
    channel: 'chrome',
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-sandbox'
    ]
  )
  
  context = browser.new_context(
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36',
    viewport: { width: 1920, height: 1080 }
  )

  page = context.new_page
  
  page.add_init_script(script: <<~JS
    delete Object.getPrototypeOf(navigator).webdriver;
    window.chrome = { runtime: {}, loadTimes: function() {}, csi: function() {}, app: {} };
    Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
    Object.defineProperty(navigator, 'plugins', {
      get: () => [
        { description: "Portable Document Format", filename: "internal-pdf-viewer", name: "Chrome PDF Plugin" },
        { description: "Portable Document Format", filename: "internal-pdf-viewer", name: "Chrome PDF Viewer" }
      ],
    });
  JS
  )

  begin
    puts "Checking bot detection..."
    page.goto('https://bot.sannysoft.com/', waitUntil: 'load')
    sleep 5
    page.screenshot(path: 'bot_check.png', fullPage: true)
    puts "Screenshot saved as bot_check.png"
  rescue StandardError => e
    puts "Error: #{e.message}"
  ensure
    browser.close
  end
end
