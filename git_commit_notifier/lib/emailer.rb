require 'yaml'

class Emailer

  def initialize(recipient, from_address, from_alias, subject, text_message, html_message, old_rev, new_rev, ref_name)
    @recipient = recipient
    @from_address = from_address
    @from_alias = from_alias
    @subject = subject
    @text_message = text_message
    @html_message = format_html(html_message)
    @ref_name = ref_name
    @old_rev = old_rev
    @new_rev = new_rev
  end

  def boundary
    return @boundary if @boundary
    srand
    seed = "#{rand(10000)}#{Time.now}"
    @boundary = Digest::SHA1.hexdigest(seed)
  end

  def format_html(html_diff)
<<EOF
<html><head>
<style>#{read_css}
</style>
</head>
<body>
#{html_diff}
</body>
</html>
EOF
  end

  def read_css
    out = ''
    File.open(File.dirname(__FILE__) + '/../stylesheets/styles.css').each { |line|
      out += line
    }
    out
  end

  def perform_delivery_smtp(content,smtp_settings)
    settings = { }
    %w(address port domain user_name password authentication).each do |key|
      val = smtp_settings[key].value.empty? ? nil : smtp_settings[key].value
      settings.merge!({ key => val})
    end
    Net::SMTP.start(settings['address'], settings['port'], settings['domain'],
                    settings['user_name'], settings['password'], settings['authentication']) do |smtp|
      smtp.open_message_stream(@from_address, [@recipient]) do |f|
        content.each do |line|
          f.puts line
          end
        end
    end
  end

  def perform_delivery_sendmail(content, sendmail_settings)
    args = '-i -t'
    args += sendmail_settings['arguments'].value
    IO.popen("#{sendmail_settings['location'].value} #{args}","w+") do |f|
      content.each do |line|
        f.puts line
      end
      f.flush
    end
  end

  def send
    config = YAML.parse_file(File.dirname(__FILE__) + '/../config/config.yml')
    from = @from_alias.empty? ? @from_address : "#{@from_alias} <#{@from_address}>"
    content = ["From: #{from}",
        "Reply-To: #{from}",
        "To: #{@recipient}",
        "Subject: #{@subject}",
        "X-Git-Refname: #{@ref_name}",
        "X-Git-Oldrev: #{@old_rev}",
        "X-Git-Newrev: #{@new_rev}",
        "Mime-Version: 1.0",
        "Content-Type: multipart/alternative; boundary=#{boundary}\n\n\n",
        "--#{boundary}",
        "Content-Type: text/plain; charset=utf-8",
        "Content-Transfer-Encoding: 8bit",
        "Content-Disposition: inline\n\n\n",
        @text_message,
        "--#{boundary}",
        "Content-Type: text/html; charset=utf-8",
        "Content-Transfer-Encoding: 8bit",
        "Content-Disposition: inline\n\n\n",
        @html_message,
        "--#{boundary}--"]
    if config['email']['delivery_method'].value == 'smtp'
      perform_delivery_smtp(content, config['smtp_server'])
    else
      perform_delivery_sendmail(content, config['sendmail_options'])
    end
  end
end
