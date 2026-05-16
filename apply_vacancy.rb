require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'playwright'
require 'fileutils'
require 'securerandom'

# Шлях до профілю браузера
user_data_dir = File.join(Dir.pwd, 'browser_profile')
FileUtils.mkdir_p(user_data_dir)

def fill_form(form_locator, page)
  puts "Заповнення форми..."
  File.write('form_dump.html', form_locator.inner_html)
  
  # find all inputs in form
  inputs = form_locator.locator('input')
  count = inputs.count
  count.times do |i|
    input = inputs.nth(i)
    type = input.get_attribute('type')
    name = input.get_attribute('name') || input.get_attribute('id') || ''
    
    next if ['hidden', 'submit', 'button', 'checkbox', 'radio'].include?(type)
    
    placeholder = input.get_attribute('placeholder') || ''
    
    val = "RandomData_#{SecureRandom.hex(4)}"
    if name.downcase.include?('email') || type == 'email' || placeholder.downcase.include?('email')
      val = "test_#{SecureRandom.hex(4)}@example.com"
    elsif name.downcase.include?('phone') || type == 'tel' || name.downcase.include?('tel') || placeholder.downcase.include?('phone')
      val = "+38050#{rand(1000000..9999999)}"
    elsif name.downcase.include?('name') || name.downcase.include?('first') || placeholder.downcase.include?('name')
      val = "John Doe #{SecureRandom.hex(2)}"
    elsif name.downcase.include?('url') || name.downcase.include?('link') || type == 'url' || placeholder.downcase.include?('linkedin')
      val = "https://linkedin.com/in/johndoe#{SecureRandom.hex(2)}"
    elsif placeholder.downcase.include?('from')
      val = "1000"
    elsif placeholder.downcase.include?('to')
      val = "2000"
    elsif type == 'file'
      begin
        File.write('dummy_cv.pdf', 'Dummy CV content for testing purposes.' * 100) unless File.exist?('dummy_cv.pdf') && File.size('dummy_cv.pdf') > 1024
        input.set_input_files('dummy_cv.pdf', timeout: 3000)
      rescue StandardError => e
        puts "Файл не завантажено: #{e.message}"
      end
      next
    end
    
    begin
      input.fill(val, timeout: 2000)
      sleep rand(0.1..0.4)
    rescue StandardError => e
      puts "Пропущено поле (невидиме або не редагується): #{name || type} - #{e.message.split("\n").first}"
    end
  end

  # find all textareas
  textareas = form_locator.locator('textarea')
  t_count = textareas.count
  t_count.times do |i|
    textarea = textareas.nth(i)
    placeholder = textarea.get_attribute('placeholder') || ''
    val = "Hello, this is a random test application message. ID: #{SecureRandom.uuid}"
    if placeholder.downcase.include?('date')
      val = "ASAP"
    elsif placeholder.downcase.include?('yes or no')
      val = "Yes"
    end
    
    begin
      textarea.fill(val, timeout: 2000)
      sleep rand(0.1..0.4)
    rescue StandardError => e
      puts "Пропущено textarea (невидима або не редагується) - #{e.message.split("\n").first}"
    end
  end
  
  # English Level handling
  begin
    lang_dropdown = nil
    level_dropdown = nil
    
    selects = form_locator.locator('.select-with-search')
    selects.count.times do |i|
      el = selects.nth(i)
      text = el.inner_text.to_s
      if text.include?('Choose language')
        lang_dropdown = el
      elsif text.include?('Choose level')
        level_dropdown = el
      end
    end
    
    if lang_dropdown
      head = lang_dropdown.locator('.select-head')
      head.click(timeout: 2000)
      sleep 1
      box = head.bounding_box
      page.mouse.click(box['x'] + 20, box['y'] + box['height'] + 30)
      sleep 1
    end
    
    if level_dropdown
      head = level_dropdown.locator('.select-head')
      head.click(timeout: 2000)
      sleep 1
      box = head.bounding_box
      # +60 to skip the first item (often "Not set")
      page.mouse.click(box['x'] + 20, box['y'] + box['height'] + 70)
      sleep 1
    end
  rescue StandardError => e
    puts "English Level selection failed: #{e.message.split("\n").first}"
  end
  
  puts "Форма заповнена. Спроба відправити..."
  submit_btn = form_locator.locator('button[type="submit"], input[type="submit"], button:has-text("Submit"), button:has-text("Відправити"), button:has-text("Send")')
  if submit_btn.count > 0
    submit_btn.first.click
    puts "Форму відправлено! Очікування відповіді сервера..."
  else
    # fallback if button is not explicitly type="submit"
    general_btn = form_locator.locator('button').last
    if general_btn.count > 0
      general_btn.click
      puts "Відправлено через останню кнопку у формі. Очікування відповіді сервера..."
    else
      puts "Кнопку відправки не знайдено."
    end
  end
  
  puts "Очікуємо до 30 секунд на повідомлення про успішну відправку..."
  begin
    success_msg = page.locator('text="Your application has been sent"')
    success_msg.first.wait_for(state: 'visible', timeout: 30000)
    puts "Отримано повідомлення: #{success_msg.first.inner_text.strip}"
  rescue StandardError => e
    begin
      success_msg_ua = page.locator('text="Ваша заявка відправлена"')
      success_msg_ua.first.wait_for(state: 'visible', timeout: 5000)
      puts "Отримано повідомлення: #{success_msg_ua.first.inner_text.strip}"
    rescue StandardError => e2
      puts "Повідомлення не з'явилося протягом очікування. Перевірте скріншот vacancy_applied.png."
    end
  end

  sleep 2
  page.screenshot(path: 'vacancy_applied.png')
end

Playwright.create(playwright_cli_executable_path: 'npx playwright') do |playwright|
  context = playwright.chromium.launch_persistent_context(
    user_data_dir,
    headless: true, # Змініть на false для локального запуску та дебагу
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
  
  page.add_init_script(script: <<~JS
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    window.chrome = { runtime: {}, loadTimes: function() {}, csi: function() {}, app: {} };
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
    Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
    const getParameter = WebGLRenderingContext.prototype.getParameter;
    WebGLRenderingContext.prototype.getParameter = function(parameter) {
      if (parameter === 37445) return 'Google Inc. (Intel)';
      if (parameter === 37446) return 'ANGLE (Intel, Intel(R) UHD Graphics 620 Direct3D11 vs_5_0 ps_5_0, D3D11)';
      return getParameter.apply(this, [parameter]);
    };
  JS
  )

  target_url = 'https://dewais.hurma.work/public-vacancies/99?source=NQ%3D%3D&utm_source=dou_ua'
  puts "Спроба зайти на #{target_url}..."
  
  begin
    page.goto(target_url, waitUntil: 'load', timeout: 60000)
    
    page.mouse.move(rand(100..500), rand(100..500))
    sleep 1
    
    puts "Очікування завантаження сторінки / проходження Cloudflare..."
    
    cloudflare_passed = false
    40.times do |i|
      title = page.title
      
      if title.include?("Just a moment") || title.include?("Checking your browser") || title.strip.empty? || title.include?("Loading")
        page.mouse.move(rand(100..800), rand(100..600)) if i % 3 == 0
        sleep 1
      else
        cloudflare_passed = true
        break
      end
    end

    if cloudflare_passed
      puts "✅ Сторінка завантажена! Заголовок: #{page.title}"
      sleep 2
      
      # Перевіряємо наявність форми
      visible_forms = page.locator('form:visible')
      if visible_forms.count > 0
        puts "Знайдено форму на поточній сторінці."
        fill_form(visible_forms.first, page)
      else
        puts "Форму не знайдено. Шукаємо кнопку переходу до форми..."
        
        # Намагаємося знайти кнопку Apply/Відгукнутися (різні варіанти)
        apply_btn = nil
        btn_locators = page.locator('button:visible, a:visible, div.v-btn__content')
        btn_locators.count.times do |i|
          el = btn_locators.nth(i)
          begin
            if el.inner_text.match?(/(Apply|Відгукнутися|Respond|Подати|Відправити)/i)
              apply_btn = el
              break
            end
          rescue StandardError
            next
          end
        end
        
        if apply_btn
          puts "Знайдено кнопку. Натискаємо..."
          apply_btn.click
          
          # Чекаємо можливого завантаження нової сторінки або модалки
          sleep 3
          
          visible_forms_after = page.locator('form:visible')
          if visible_forms_after.count > 0
            puts "Знайдено форму після кліку."
            fill_form(visible_forms_after.first, page)
          else
            puts "Форму так і не знайдено після кліку."
            page.screenshot(path: 'no_form_after_click.png')
          end
        else
          puts "Кнопку для переходу до форми не знайдено."
          page.screenshot(path: 'no_apply_button.png')
        end
      end
    else
      puts "❌ Cloudflare заблокував запит або сторінка вантажиться занадто довго."
      page.screenshot(path: 'failed_cloudflare.png')
    end
  rescue StandardError => e
    puts "Помилка під час виконання: #{e.message}"
    page.screenshot(path: 'error.png') rescue nil
  ensure
    context.close
  end
end
