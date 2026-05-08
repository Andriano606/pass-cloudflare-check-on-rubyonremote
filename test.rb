require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'playwright'
require 'fileutils'

# Шлях до профілю браузера (допомагає проходити перевірки)
user_data_dir = File.join(Dir.pwd, 'browser_profile')
FileUtils.mkdir_p(user_data_dir)

Playwright.create(playwright_cli_executable_path: 'npx playwright') do |playwright|
  # Використовуємо launch_persistent_context для кращої імітації реального користувача
  context = playwright.chromium.launch_persistent_context(
    user_data_dir,
    headless: true, # Змініть на false для локального запуску
    channel: 'chrome',
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-sandbox',
      '--disable-setuid-sandbox'
    ],
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.7727.116 Safari/537.36',
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  )

  page = context.pages.first || context.new_page
  
  # Просунутий Stealth скрипт
  page.add_init_script(script: <<~JS
    // 1. Приховуємо автоматизацію
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });

    // 2. Імітуємо об'єкт chrome
    window.chrome = {
      runtime: {},
      loadTimes: function() {},
      csi: function() {},
      app: {}
    };

    // 3. Імітуємо плагіни (важливо для Cloudflare)
    const makePlugin = (data) => {
      const p = Object.create(Plugin.prototype);
      Object.assign(p, data);
      return p;
    };
    const plugins = [
      makePlugin({ name: 'Chrome PDF Viewer', filename: 'internal-pdf-viewer', description: 'Portable Document Format' }),
      makePlugin({ name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' })
    ];
    Object.defineProperty(navigator, 'plugins', { get: () => plugins });

    // 4. Імітуємо мови
    Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });

    // 5. Мокаємо WebGL
    const getParameter = WebGLRenderingContext.prototype.getParameter;
    WebGLRenderingContext.prototype.getParameter = function(parameter) {
      if (parameter === 37445) return 'Google Inc. (Intel)';
      if (parameter === 37446) return 'ANGLE (Intel, Intel(R) UHD Graphics 620 Direct3D11 vs_5_0 ps_5_0, D3D11)';
      return getParameter.apply(this, [parameter]);
    };
  JS
  )

  puts "Спроба зайти на RubyOnRemote з використанням профілю..."
  
  begin
    # Переходимо на сайт
    page.goto('https://rubyonremote.com/', waitUntil: 'load', timeout: 60000)
    
    # Імітуємо активність людини відразу після завантаження
    page.mouse.move(rand(100..500), rand(100..500))
    sleep 1
    
    puts "Очікування завершення перевірки Cloudflare..."
    
    success = false
    40.times do |i|
      title = page.title
      puts "Поточний заголовок [#{i}]: #{title}"
      
      if title.include?("Just a moment") || title.include?("Checking your browser") || title.strip.empty? || title.include?("Loading")
        page.mouse.move(rand(100..800), rand(100..600)) if i % 3 == 0
        sleep 1
      else
        # Перевіряємо чи це дійсно сайт, а не сторінка помилки
        if title.downcase.include?("ruby") || title.downcase.include?("remote")
          success = true
          break
        else
          # Можливо ще вантажиться
          sleep 1
        end
      end
    end

    if success
      puts "✅ Успішний вхід!"
      puts "Заголовок сторінки: #{page.title}"
      
      sleep 2
      page.screenshot(path: 'success.png', fullPage: true)
      puts "Скріншот збережено як success.png"
      
      # Виведемо частину контенту для перевірки
      puts "Знайдено тексту на сторінці: #{page.inner_text('body').length} символів"
    else
      puts "❌ Cloudflare заблокував запит або перевірка триває занадто довго."
      page.screenshot(path: 'failed_cloudflare.png')
      puts "Скріншот збережено як failed_cloudflare.png"
      
      # Спробуємо зрозуміти причину з тексту сторінки
      puts "Текст на сторінці помилки (перші 200 символів):"
      puts page.inner_text('body')[0..200]
    end
  rescue StandardError => e
    puts "Помилка під час виконання: #{e.message}"
    page.screenshot(path: 'error.png') rescue nil
  ensure
    context.close
  end
end
