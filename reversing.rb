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
    (16..ws.num_rows).each do |row|
      unless ws[row, 1].match(/obs customer|google llc|proxad \/ free sas|\(not set\)|end-user numericable|bouygues telecom division mobile|orange mobile|free mobile sas|pool for broadband dsl customers|fixed ip|dynamic pools|online sas|orange s.a.|celeste sas|pool for broadband cable customers|orange|equation sa|static ip|ovh telecom|sfr sa|eurafibre sas|free sas|bouygues telecom res division for|completel sas france|  pool for retail ftth customers|sfr entreprise|pool for cable customers|wifirst end users|broadband pool|f4862-00067-001|lnaub656 aubervilliers bloc 1|lnstl657 saint lambert bloc 2|lnput658 puteaux bloc 2|lnmso656 montsouris bloc 1|societe francaise du radiotelephone s.a.|pool for broadband ftth customers|lnmso656 montsouris bloc 1|dedibox sas|sewan communications s.a.s.|societe francaise du radiotelephone s.a.|bsmso682 montsouris bloc 1|eurafibre euratechnologies|dsl|bsmso682 montsouris bloc 1|f5851-00001-001|ovh sas|services platform|telefonica de espana sau|time warner cable internet llc|deutsche telekom ag|ebox|eurafibre-euratech01|lnmso657 montsouris bloc 2|lnnly657 neuilly bloc 2|nerim sas|  pool for retail dsl customers|1&1 versatel deutschland gmbh|adsl_maroc_telecom|bsput652 puteaux bloc 1|bsput652 puteaux bloc 2|bsput682 puteaux bloc 2|colt technology services group limited|customer-route-civ01|digiweb ltd.|dsl - end users|fullroute|  internet services|interoute communications limited|lespace|lnput657 puteaux bloc 1|lnput658 puteaux bloc 1|lnstl657 st lambert bloc 1|lnstl658 saint lambert bloc 1|lnstl658 saint lambert bloc 2|maroctelecomasdl|pool for mobile data users|private customer|red de servicios ip| ripe network coordination center|residential dhcp|sympatico hse|urban wimax assigned ip address|videotron ltee|viettel group|xtra telecom s.a.|zayo france sas|amazon technologies inc.|ans communications inc|bsaub681 aubervilliers bloc 2|bsaub682 aubervilliers bloc 2|bslil654 lille bloc 1| bsmso681 montsouris bloc 1|bsmso682 montsouris bloc 2|bsput681 puteaux bloc 1|bsput682 puteaux bloc 1|customer pppoe static delivery fr|epm telecomunicaciones s.a. e.s.p.|excell hosted customers cn|fpt telecom company|ftth|ftth - end users|galop telecom|global crossing|hutchison max telecom limited|iinet limited|infonet services corporation|lewisham|lnaub656 aubervilliers bloc 2|lnmso657 montsouris bloc 1|lnnly656 neuilly bloc 1| lnput656 puteaux bloc 1|lnput656 puteaux bloc 2|lnstl656 st lambert bloc 1|lnstl656 st lambert bloc 2|lnstl657 st lambert bloc 2|m247 ltd paris infrastructure|matooma|mci communications services inc.  verizon business|mpls network|paradise networks llc|po box 50081|pool for enterprise customers|pop bor|pop lyon|pop montsouris|pop puteaux|pt telkom indonesia|re:sources france sas|saint lambert bloc 1|sas cts computers and telecommunications systems|service fttx|southampton|t-mobile thuis b.v.|te data|telecom paristech|telenet operaties n.v.|telmex colombia s.a.|upc slovakia|verlingue|ziggo rotterdam internal ipms for soho|koba sp. z o.o.|leonix telecom customer network|leonix telecom network|libyan telecom and technology|lille|luxembourg online s.a.|megacable comunicaciones de mexico s.a. de c.v.|liverpool|bloc|adsl-go-plus|.*bloc.*|.*telecom.*|.*network.*|.*adsl.*|.*dsl.*|.*pool.*|.*cable.*|.*fibre.*|.*internet service.*|.*customer.*|.*telemar.*|.*communication.*|.* ip .*|advantage interactive limited|.* amazon .*|amazon .*|amazon.com inc|.* telecom .*|.* communication .*|.* verizon .*|.*euratech.*|.*internet.*|14-16 rue voltaire|4g|.* ip .*|alcatel-lucent|.*metropole.*|aapt limited|2talk limited|2degrees|belarusian-american joint venture cosmos tv ltd|.*02 online.*|a100 row gmbh|925 n la brea ave tenant llc|.*subnet.*|.*mobility.*|^bcl.*|.*airtel.*|.*backbone.*|avinor as|altibox as|audit conseil|bath|.*altitude infrastructure exploitation sas.*|.*pool.*|adista sas|appliwave sas|arcor ag|anonima italiana alberghi spa|.*networks.*|.*network.*|ate adc|avea iletisim hizmetleri a.s|.*mobile.*|.* mobile .*|.* telenet .*|.* universite .*|northampton east|infraestructura red y servicios ip|andrews & arnold ltd|zscaler inc.|.*vodafone.*|vodafone.*|nt brasil tecnologia ltda. me|t-systems international gmbh|.*t-systems.*|telekom.*|.*telekom.*|sky uk limited|singnet pte ltd|pool\s?|bloc\s?|proxad|cable|free s|radiotel|orange|.?dsl|tele[kc]+om|tele[phf]+o|video|mobile|wireless|broadband|internet|fibre| ip |gprs|provider|[a-z ]+[0-9]+[a-z ]+|obs cu|\(not set\)|network|static ip|^test$|host(ing|ed)|isp|backbone|dhcp|ip address|dynamic|dialup|server|platform|inap z|completel|jet ?multi|users|aol|rue louvrex 95|brutele sc$|telenet|p&t|fttx|ovh (sas|sys)|verizon|online|belgacom|swisscom|psinet|nordnet|colt|citevision|service nsaii$|inktomi|yahoo|consumer|.*infrastructure.*|etb - colombia|ziggo b.v.|quadranet inc.|brennercom ag\/spa|chandigarh|exponential-e ltd.|claro s.a.|.*university.*|.*net.*|.*[0-9]{6}.*|abts tamilnadu|digiweb ltd|dna oyj|elisa oyj|.*wimax.*|myrepublic ltd|global delivery center india private limited|owla residential building|rede brasileira de comunicacao ltda| jazztel triple play services|pop.*|organisation|telenor a\/s|tata teleservices limited -gsm division|uic|zscaler.*|versatel.*|telia lietuva ab|expereo international bv|digitalocean llc|client - rtpe services/)
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
           @index == (@ips.size - 1) ? @index = 0 : @index += 1
           sleep(150)
          retry if retries < 10
        end
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
