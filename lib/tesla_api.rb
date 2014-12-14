class TeslaApi
  include HTTParty
  base_uri "https://owner-api.teslamotors.com/api/1"
  format :json

  def initialize(email, password)
    @email = email
    response = self.class.post(
        "https://owner-api.teslamotors.com/oauth/token",
        body: {
            "grant_type" => "password",
            "client_id" => "e4a9949fcfa04068f59abb5a658f2bac0a3428e4652315490b659d5ab3f35a9e",
            "client_secret" => "c75f14bbadc8bee3a7594412c31416f8300256d7668ea7e6e7f06727bfb9d220",
            "email" => email,
            "password" => password
        }
    )
    self.class.headers "Authorization" => "Bearer #{response["access_token"]}"
  end

  def vehicles
    self.class.get("/vehicles")["response"].map { |v| Vehicle.new(self.class, @email, v["id"], v) }
  end

  class Vehicle
    attr_accessor :api, :email, :id, :vehicle

    def initialize(api, email, id, vehicle)
      @api = api
      @email = email
      @id = id
      @vehicle = vehicle
    end

    def [](key)
      vehicle[key]
    end

    # State

    def mobile_enabled
      api.get("/vehicles/#{id}/mobile_enabled")["result"]
    end

    def charge_state
      api.get("/vehicles/#{id}/data_request/charge_state")
    end

    def climate_state
      api.get("/vehicles/#{id}/data_request/climate_state")
    end

    def drive_state
      api.get("/vehicles/#{id}/data_request/drive_state")
    end

    def gui_settings
      api.get("/vehicles/#{id}/data_request/gui_settings")
    end

    def vehicle_state
      api.get("/vehicles/#{id}/data_request/vehicle_state")
    end

    # Commands

    def wake_up
      api.post("/vehicles/#{id}/wake_up")
    end

    def charge_port_door_open
      api.post("/vehicles/#{id}/command/charge_port_door_open")
    end

    def charge_standard
      api.post("/vehicles/#{id}/command/charge_standard")
    end

    def charge_max_range
      api.post("/vehicles/#{id}/command/charge_max_range")
    end

    def set_charge_limit(percent)
      api.post("/vehicles/#{id}/command/set_charge_limit", query: {state: "set", percent: percent})
    end

    def charge_start
      api.post("/vehicles/#{id}/command/charge_start")
    end

    def charge_stop
      api.post("/vehicles/#{id}/command/charge_stop")
    end

    def flash_lights
      api.post("/vehicles/#{id}/command/flash_lights")
    end

    def honk_horn
      api.post("/vehicles/#{id}/command/honk_horn")
    end

    def door_unlock
      api.post("/vehicles/#{id}/command/door_unlock")
    end

    def door_lock
      api.post("/vehicles/#{id}/command/door_lock")
    end

    def set_temps(driver_temp, passenger_temp)
      api.post("/vehicles/#{id}/command/set_temps", query: {driver_temp: driver_temp, passenger_temp: passenger_temp})
    end

    def auto_conditioning_start
      api.post("/vehicles/#{id}/command/auto_conditioning_start")
    end

    def auto_conditioning_stop
      api.post("/vehicles/#{id}/command/auto_conditioning_stop")
    end

    def sun_roof_control(state)
      api.post("/vehicles/#{id}/command/sun_roof_control", query: {state: state})
    end

    def sun_roof_move(percent)
      api.post("/vehicles/#{id}/command/sun_roof_control", query: {state: "move", percent: percent})
    end

    # Streaming

    def stream(&reciever)
      EventMachine.run do
        request = EventMachine::HttpRequest.new(
            "https://streaming.vn.teslamotors.com/stream/#{self["vehicle_id"]}/" +
                "?values=speed,odometer,soc,elevation,est_heading,est_lat,est_lng,power")

        http = request.get(
            head: {
                "authorization" => [
                    email,
                    self["tokens"].first
                ]
            },
            inactivity_timeout: 15)

        http.stream do |chunk|
          attributes = chunk.split(",")
          reciever.call({
                            time: DateTime.strptime((attributes[0].to_i/1000).to_s, "%s"),
                            speed: attributes[1].to_f,
                            odometer: attributes[2].to_f,
                            soc: attributes[3].to_f,
                            elevation: attributes[4].to_f,
                            est_heading: attributes[5].to_f,
                            est_lat: attributes[6].to_f,
                            est_lng: attributes[7].to_f,
                            power: attributes[8].to_f
                        })
        end

        http.callback { EventMachine.stop }
        http.errback { EventMachine.stop }
      end
    end
  end
end
