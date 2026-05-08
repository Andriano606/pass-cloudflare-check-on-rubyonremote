require 'rubygems'
require 'bundler/setup'
Bundler.require # Це примусово завантажить всі геми з Gemfile

require 'playwright-ruby-client'

# Використовуємо npx як шлях до виконуваного файлу
Playwright.create(playwright_cli_executable_path: 'npx playwright') do |playwright|
  # launch(headless: true) обов'язковий для перших тестів, 
  # щоб ви бачили, чи не з'явилася капча
  browser = playwright.chromium.launch(headless: true)
  
  context = browser.new_context(
    user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 720 }
  )

  page = context.new_page
  
  # Приховуємо ознаки автоматизації
  page.add_init_script(script: <<~JS
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    window.chrome = { runtime: {} };
  JS
  )

  puts "Спроба зайти на RubyOnRemote..."
  
  begin
    # Переходимо на сайт
    page.goto('https://rubyonremote.com/', wait_until: 'domcontentloaded')
    
    # Cloudflare може перевіряти вас 2-5 секунд
    puts "Очікування завершення перевірки Cloudflare..."
    sleep 8

    if page.title.include? "Just a moment"
      puts "❌ Cloudflare заблокував запит або вимагає ручного вирішення капчі."
    else
      puts "✅ Успішний вхід!"
      puts "Заголовок сторінки: #{page.title}"
      
      # Зробимо скріншот, щоб переконатися, що все завантажилось
      page.screenshot(path: 'success.png')
      puts "Скріншот збережено як success.png"
    end
  rescue StandardError => e
    puts "Помилка під час виконання: #{e.message}"
  ensure
    browser.close
  end
end