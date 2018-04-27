# encoding: utf-8
require 'mysql2'
require 'open-uri'
require 'net/https'
require 'nokogiri'
require 'google_drive'

POSITIONS = ['CTO', 'CEO']
PROXY_USERNAME = '{{YOUR_USER_NAME}}'
PROXY_PASSWORD = '{{YOUR_PASSWORD}}'

class Reversing

  def initialize
    sheets = parsing_spreadsheets
    getting_ips
    going_through_regex(sheets[0], sheets[1])
    searching_database
    searching_pipedrive
    searching_domains
    searching_names
    searching_mails
    storing_database
    storing_spreadsheets(sheets[0], sheets[1])
    sending_report
  end

  def parsing_spreadsheets
    session = GoogleDrive::Session.from_config("config.json")
    ws = session.spreadsheet_by_key("{{YOUR_KEY_URL}}").worksheets[1]
    ns = session.spreadsheet_by_key("{{YOUR_KEY_URL}}").worksheets[2]
    ns.delete_rows(1, ns.max_rows)
    ns[1, 1] = 'Original name'
    ns[1, 2] = 'Guessed name'
    ns[1, 3] = 'Guessed domain'
    ns[1, 4] = "#{POSITIONS.first} name"
    ns[1, 5] = "#{POSITIONS.first} mail"
    ns[1, 6] = "#{POSITIONS.last} name"
    ns[1, 7] = "#{POSITIONS.last} mail"
    ns[1, 8] = "Numbers of visits"
    ns[1, 9] = "Pipedrive URL"
    ns.save
    [ws, ns]
  end

  def getting_ips
    @index = 0
    @ips = []
    nordvpn_fr_recommandations = Net::HTTP.get(URI.parse("https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations&filters={%22country_id%22:74,%22servers_groups%22:[11],%22servers_technologies%22:[9]}&lang=fr"))
    nordvpn_fr_recommandations_parsed = JSON.parse(nordvpn_fr_recommandations)
    nordvpn_fr_recommandations_parsed.each { |server| @ips << 'http://' + server['hostname'] }
  end

  def going_through_regex(ws, ns)
    @companies = []    
    isp_regex = Net::HTTP.get(URI.parse("https://raw.githubusercontent.com/gvdh/Daily-traffic-report/master/isp_regex"))
    (16..ws.num_rows).each do |row|
      unless ws[row, 1].match(isp_regex)
        @companies << {
          original_name: ws[row, 1]
        }
      end
    end
  end

  def searching_database
    @client = Mysql2::Client.new(:host => "localhost", :username => "{{YOUR_USERNAME}}", :password => "{{YOUR_PASSWORD}}", :database => "reversing")
    counter = 0
    @companies.each do |company|
      result = @client.query("SELECT * FROM reversed WHERE original_name = '#{company[:original_name]}'")
      if result.size > 0 
        company.merge!({found_in_db: 'sql'})
        symbolized_company = result.first.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        company.merge!(symbolized_company)
        counter += 1
      end
    end
  end

  def searching_pipedrive
    counter = 0
    @companies.each do |company|
      unless company[:pipedrive_url]
        name_without_suffixes = company[:original_name].gsub(/\b(\,?\s*)*(ltd|limited|inc(?:orporated)?|co(?:rp|mpany|rporation)?|p\.?[a|c]\.?|p?\.?(?:l?\.?){1,3}[c|p|a]\.?)(\.)*$|s.a./, '')
        result = JSON.parse(Net::HTTP.get(URI.parse("https://api.pipedrive.com/v1/organizations/find?term=#{name_without_suffixes}&start=0&api_token={{YOUR_API_KEY}}")))
        if result["data"]
          company.merge!({
            found_in_db: (company[:found_in_db] ? company[:found_in_db] : 'pipedrive' ),
            name: (company[:name] ? company[:name] : '' ),
            domain: (company[:domain] ? company[:domain] : '' ),
            position_1_name: (company[:position_1_name] ? company[:position_1_name] : '' ),
            position_1_mail: (company[:position_1_mail] ? company[:position_1_mail] : '' ),
            position_2_name: (company[:position_2_name] ? company[:position_2_name] : '' ),
            position_2_mail: (company[:position_2_mail] ? company[:position_2_mail] : '' ),
            number_of_visits: (company[:number_of_visits] ? company[:number_of_visits] : 1 ),
            pipedrive_url: "https://{{YOUR_COMPANY_NAME}}.pipedrive.com/organization/#{result["data"].first["id"]}"
            })
          counter += 1
        end
      end
    end
  end

  def searching_domains
    @companies.each do |company|
      unless company[:found_in_db]
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
            else
              company.merge!({
                found_in_db: 'no_domain',
                name: '', 
                domain: '', 
                position_1_name: '', 
                position_1_mail: '', 
                position_2_name: '', 
                position_2_mail: '',
                number_of_visits: '',
                pipedrive_url: '',
                })
            end
          end
          @index == (@ips.size - 1) ? @index = 0 : @index += 1
          sleep(150)
        rescue
          retries += 1
          @index == (@ips.size - 1) ? @index = 0 : @index += 1
          retry if retries < 10
        end
      end
    end
  end

  def searching_names
    @companies.select {|company| company[:domain] }.each do |company|
      POSITIONS.each_with_index do |position, index|
        unless company[:found_in_db]
          retries = 0
          begin
            @proxy_uri = URI.parse(@ips[@index])
            url = URI.parse(URI.encode("https://www.google.fr/search?q=#{company[:name]} #{position} site:linkedin.com"))
            doc = Nokogiri::HTML(open(url, proxy_http_basic_authentication: [@proxy_uri, PROXY_USERNAME, PROXY_PASSWORD], 'User-agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2", 'read_timeout' => '10' ).read)
            @index == (@ips.size - 1) ? @index = 0 : @index += 1
          rescue
            retries += 1
            @index == (@ips.size - 1) ? @index = 0 : @index += 1
            sleep(150)
           retry if retries < 10
          end
          unless doc.search('.r').text().scan(/(.*?)(?=[-|])/).first.nil?
            company.merge!({ 
              "position_#{index+1}_name".to_sym => doc.search('.r').text().scan(/(.*?)(?=[-|])/).first.first,
              "position_#{index+1}_mail".to_sym => ''  
              })
          end
          sleep(150)
        end
      end
    end
  end

  def searching_mails
    POSITIONS.each_with_index do |position, index|
      @companies.select {|company| company["position_#{index+1}_name".to_sym] }.each do |company|
        unless company[:found_in_db]
          searched_name = company["position_#{index+1}_name".to_sym].split(" ")
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
            response.each { |header| company.merge!({ "position_#{index+1}_mail".to_sym => mail }) if header == 'set-cookie' }
            break if company["position_#{index+1}_mail".to_sym]
          end
          # searching_through_voilanorbert(company, position, index) unless company["position_#{index+1}_mail".to_sym]
        end
      end
    end
  end

  def searching_through_voilanorbert(company, position, index)
    uri = URI.parse("https://api.voilanorbert.com/2016-01-04/search/name")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth("{{YOUR_NAME}}", "{{YOUR_API_KEY}}")
    request.body = "domain=#{company[:domain]}&name=#{company["position_#{index+1}_name".to_sym]}"
    req_options = {
      use_ssl: uri.scheme == "https",
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    unless JSON.parse(response.body)["email"].nil?
      company.merge!({"position_#{index+1}_mail".to_sym => JSON.parse(response.body)["email"]["email"]})
    end 
  end

  def storing_database
    @companies.each do |company|
      if company[:found_in_db] == 'sql'
        @client.query("UPDATE reversed SET number_of_visits = number_of_visits + 1 WHERE original_name = '#{company[:original_name]}'")
        @client.query("UPDATE reversed SET pipedrive_url = '#{company[:pipedrive_url]}' WHERE original_name = '#{company[:original_name]}'")
      else
        escaped_company = company
        escaped_company.each{ |k,v| escaped_company[k] = @client.escape(v) if v.is_a? String }
        @client.query("INSERT INTO reversed (original_name, name, domain, position_1_name, position_1_mail, position_2_name, position_2_mail, number_of_visits, pipedrive_url) VALUES ('#{escaped_company[:original_name]}', '#{escaped_company[:name]}', '#{escaped_company[:domain]}', '#{escaped_company[:position_1_name]}', '#{escaped_company[:position_1_mail]}', '#{escaped_company[:position_2_name]}', '#{escaped_company[:position_2_mail]}', 1, '#{escaped_company[:pipedrive_url]}')");
      end
    end
  end

  def storing_spreadsheets(ws, ns)
    @companies.each do |company|
      company.delete(:found_in_db) if company[:found_in_db]
      company[:number_of_visits] = 1 unless company[:number_of_visits].to_i >= 1
      ns_row = ns.max_rows + 1
      company.values.each_with_index { |v, i| ns[ns_row, i + 1] = v }
      ns.save
    end
  end

  def sending_report
    uri = URI.parse("{{YOUR_WEB_APP_URL}}")
    Net::HTTP.get(uri)
  end

end

Reversing.new()
