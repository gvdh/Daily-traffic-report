# encoding: utf-8
require 'open-uri'
require 'net/https'
require 'uri'
require 'nokogiri'
require 'google_drive'

POSITIONS = [['CTO'], ['CEO']]
PROXY_USERNAME = 'YOUR_USERNAME'
PROXY_PASSWORD = 'YOUR_PASSWORD'

class Reversing

  def initialize
    @index = 0
    @companies = []
    @ips = []
    sheets = parsing_spreadsheets
    getting_ips
    going_through_regex(sheets[0], sheets[1])
    searching_domains
    searching_names
    searching_mails
    storing_spreadsheets(sheets[0], sheets[1])
    sending_report
  end

  def parsing_spreadsheets
    session = GoogleDrive::Session.from_config("config.json")
    ws = session.spreadsheet_by_key("YOUR_URL_KEY").worksheets[1]
    ns = session.spreadsheet_by_key("YOUR_URL_KEY").worksheets[2]
    ns.delete_rows(1, ns.max_rows)
    ns[1, 1] = 'Service provider'
    ns[1, 2] = 'Guessed domain'
    ns[1, 3] = 'CTO Name'
    ns[1, 4] = 'CEO Name'
    ns[1, 5] = 'CEO Mail'
    ns[1, 6] = 'CTO Mail'
    ns.save
    [ws, ns]
  end

  def getting_ips
    nordvpn_fr_recommandations = Net::HTTP.get(URI.parse("https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations&filters={%22country_id%22:74,%22servers_groups%22:[11],%22servers_technologies%22:[9]}&lang=fr"))
    nordvpn_fr_recommandations_parsed = JSON.parse(nordvpn_fr_recommandations)
    nordvpn_fr_recommandations_parsed.each { |server| @ips << 'http://' + server['hostname'] }
  end

  def going_through_regex(ws, ns)
    isp_regex = Net::HTTP.get(URI.parse("https://raw.githubusercontent.com/gvdh/Daily-traffic-report/master/isp_regex"))
    (16..ws.num_rows).each do |row|
      unless ws[row, 1].match(isp_regex)
        @companies << {
          original_name: ws[row, 1]
        }
      end
    end
  end

  def searching_domains
    @companies.each do |company|
      retries = 0
      begin
        @proxy_uri = URI.parse(@ips[@index])
        doc = Nokogiri::HTML(open(URI.parse("http://www.google.fr/search?q=#{company[:original_name]}"), proxy_http_basic_authentication: [@proxy_uri, PROXY_USERNAME, PROXY_PASSWORD], 'User-agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2").read)
        doc.search('.r > a').first(1).each do |url|
          parsed_url = url.attr('href').match(/^(?:https?:)?(?:\/\/)?(?:[^@\n]+@)?(?:www\.)?([^:\/\n]+)/)
          clearbit = JSON.parse(open("https://autocomplete.clearbit.com/v1/companies/suggest?query=#{parsed_url[1]}").read)
          unless clearbit.empty? || clearbit.first['name'].match(/Bloomberg|Zauba Technologies|Société 2015|D&B Hoovers|RIPE NCC|IPInfo/)
            company.merge!({
              name: clearbit.first['name'],
              domain: clearbit.first['domain']
            })
            break
          end
        end
        @index == @ips.size ? @index = 0 : @index += 1
        sleep(150)
      rescue
        retries += 1
        @index == @ips.size ? @index = 0 : @index += 1
        retry if retries < 10
      end
    end
  end

  def searching_names
    @companies.select {|company| company[:domain] }.each do |company|
      POSITIONS.each do |position|
        retries = 0
        begin
          @proxy_uri = URI.parse(@ips[@index])
          url = URI.parse(URI.encode("https://www.google.fr/search?q=#{company[:name]} #{position.first} site:linkedin.com"))
          doc = Nokogiri::HTML(open(url, proxy_http_basic_authentication: [@proxy_uri, PROXY_USERNAME, PROXY_PASSWORD], 'User-agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2", 'read_timeout' => '10' ).read)
          @index == @ips.size ? @index = 0 : @index += 1
        rescue
          retries += 1
          @index == @ips.size ? @index = 0 : @index += 1
          sleep(150)
         retry if retries < 10
        end
        company.merge!({ "#{position.first}".to_sym => doc.search('.r').text().scan(/(.*?)(?=[-|])/).first.first}) unless doc.search('.r').text().scan(/(.*?)(?=[-|])/).first.nil?
        sleep(150)
      end
    end
  end

   def searching_mails
    POSITIONS.each do |position|
      @companies.select {|company| company[position.first.to_sym] }.each do |company|
        retries = 0
        begin
          searched_name = company[position.first.to_sym].split(" ")
          if searched_name.size == 2
            mails = ["#{searched_name[0]}@#{company[:domain]}", "#{searched_name[1]}@#{company[:domain]}", "#{searched_name[0]}.#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1]}.#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0]}#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1]}#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0]}-#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1]}-#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0]}_#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1]}_#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0][0]}.#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1][0]}.#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0][0]}-#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1][0]}-#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0][0]}_#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1][0]}_#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0][0]}#{searched_name[1]}@#{company[:domain]}", "#{searched_name[1][0]}#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0][0]}.#{searched_name[1][0]}@#{company[:domain]}", "#{searched_name[1][0]}.#{searched_name[0][0]}@#{company[:domain]}", "#{searched_name[0][0]}#{searched_name[1][0]}@#{company[:domain]}", "#{searched_name[1][0]}#{searched_name[0][0]}@#{company[:domain]}", "#{searched_name[0][0]}-#{searched_name[1][0]}@#{company[:domain]}", "#{searched_name[1][0]}-#{searched_name[0][0]}@#{company[:domain]}", "#{searched_name[0][0]}_#{searched_name[1][0]}@#{company[:domain]}", "#{searched_name[1][0]}_#{searched_name[0][0]}@#{company[:domain]}"] 
          elsif searched_name.size == 1
            mails = ["#{searched_name[0]}@#{company[:domain]}", "#{searched_name[0][0]}@#{company[:domain]}"]
          else 
            mails = [] 
          end
          mails.each do |mail|
            uri = URI.parse("https://mail.google.com/mail/gxlu?email=#{mail}")
            response = Net::HTTP.get_response(uri)
            response.each { |header| company.merge!({ "#{position}_mail".to_sym => mail }) if header == 'set-cookie' }
            break if company["#{position}_mail".to_sym]
          end
        rescue
           retries += 1
           @index == @ips.size ? @index = 0 : @index += 1
           sleep(150)
          retry if retries < 10
        end
        # Uncomment line below if you want to make requests on Voilanorbert's API when mail recognition above failed.
        # searching_through_voilanorbert(company, position) unless company["#{position}_mail".to_sym]
      end
    end
  end

  def searching_through_voilanorbert(company, position)
    uri = URI.parse("https://api.voilanorbert.com/2016-01-04/search/name")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth("YOUR_NAME", "YOUR_API_KEY")
    request.body = "domain=#{company[:domain]}&name=#{company[position.first.to_sym]}"
    req_options = {
      use_ssl: uri.scheme == "https",
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    unless JSON.parse(response.body)["email"].nil?
      company.merge!({"#{position}_mail".to_sym => JSON.parse(response.body)["email"]["email"]})
    end 
  end
  

  def storing_spreadsheets(ws, ns)
    @companies.each do |company|
      ns_row = ns.max_rows + 1
      company.values.each_with_index { |v, i| ns[ns_row, i + 1] = v }
      ns.save
    end
  end

  def sending_report
    uri = URI.parse("YOUR_WEB_APP_URL")
    Net::HTTP.get(uri)
  end

end

Reversing.new()
