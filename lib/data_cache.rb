class DataCache
  def self.telemetry
    telematics = InfluxdbData.new.telematics(Time.parse(ENV["START_TIME"]), Time.parse(ENV["END_TIME"]))
    return if telematics.blank?
    telemetry = telematics.map { |t| {lat: t["est_lat"], lng: t["est_lng"]} }
    $redis.set("car-telemetry", telemetry.to_json)
  end

  def self.state
    tesla_api = TeslaApi::Client.new(ENV["TESLA_EMAIL"], ENV["TESLA_PASS"], ENV["TESLA_CLIENT_ID"], ENV["TESLA_CLIENT_SECRET"])
    ms = tesla_api.vehicles.first
    return if ms.state != "online"
    state = ms.charge_state.merge(ms.drive_state).merge(ms.climate_state).to_json
    $redis.set("car-state", state)
  end
end
