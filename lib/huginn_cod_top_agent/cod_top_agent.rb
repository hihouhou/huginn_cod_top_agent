module Agents
  class CodTopAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1d'

    description do
      <<-MD
      The huginn Cod Top Agent creates an event about a top type with a user list.

      `debug` is used to verbose mode.

      `type` is for the wanted top like top1/kills/top5.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "type": "top1",
            "game": "cod",
            "classement": {
              "XXXXXXXXXXXXXXXXX": "68",
              "ZZZZZZZZZZZZZZ": "64",
              "WWWWWWWWWWWWWWWW": "59",
              "YYYYYYYYYYYYYYY": "13"
            }
          }
    MD

    def default_options
      {
        'type' => 'top1',
        'users' => 'user1 user2 user3 user4',
        'debug' => 'false',
        'changes_only' => 'true'
      }
    end
    form_configurable :users, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :changes_only, type: :boolean
    form_configurable :type, type: :array, values: ['top1', 'kills', 'kdRatio']
    def validate_options
      unless options['users'].present?
        errors.add(:base, "users is a required field")
      end
      errors.add(:base, "categories must be provided") if interpolated['type'] == 'report' && !options['categories'].present?


      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      top interpolated['users']
    end

    private

    def top(users)
      case interpolated['type']
      when "top1"
        wanted_type = "wins"
      when "kills"
        wanted_type = "kills"
      when "kdRatio"
        wanted_type = "kdRatio"
      else
        log "Error: type has an invalid value (#{interpolated['type']})"
      end
      top = []
      payload = { "type" => "#{interpolated['type']}", "game" => "cod", "classement" => {} }
      log "top_#{interpolated['type']} launched"
      users_array = users.split(" ")
      users_array.each do |item, index|
          json = fetch(item)
          username  = json['data']['uno']
          nbr_top = json['data']['lifetime']['mode']['br']['properties']["#{wanted_type}"]
          if interpolated['debug'] == 'true'
            log "#{username} #{nbr_top}"
          end
          top << { :username => username, :nbr => nbr_top }
      end
      top = top.sort_by { |hsh| hsh[:nbr] }.reverse
      top.each do |top|
        if interpolated['debug'] == 'true'
          log "#{top[:username]}: #{top[:nbr]}"
        end
        payload.deep_merge!({"classement" => { "#{top[:username]}" => "#{top[:nbr]}" }})
      end
      log "conversion done"
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['top_suicide']
          memory['top_suicide'] = payload.to_s
          create_event payload: payload.to_json
        end
      else
        create_event payload: payload
        if payload.to_s != memory['top_suicide']
          memory['top_suicide'] = payload
        end
      end
    end

    def fetch(user)
      encoded_user = URI.encode_www_form_component(user)
      uri = URI.parse("https://app.wzstats.gg/v2/player?username=#{encoded_user}&platform=acti")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:99.0) Gecko/20100101 Firefox/99.0"
      request["Accept"] = "application/json, text/plain, */*"
      request["Accept-Language"] = "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3"
      request["Origin"] = "https://wzstats.gg"
      request["Connection"] = "keep-alive"
      request["Referer"] = "https://wzstats.gg/"
      request["Sec-Fetch-Dest"] = "empty"
      request["Sec-Fetch-Mode"] = "cors"
      request["Sec-Fetch-Site"] = "same-site"
      request["Dnt"] = "1"
      request["Pragma"] = "no-cache"
      request["Cache-Control"] = "no-cache"
      request["Te"] = "trailers"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      if interpolated['debug'] == 'true'
        log "request status for #{user} : #{response.code}"
      end
      JSON.parse(response.body)
    end
  end
end
