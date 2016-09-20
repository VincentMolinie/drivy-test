require "json"
require "date"

# your code
dataFile = File.read('data.json')
data = JSON.parse(dataFile)

pricesPerCar = {}
data['cars'].each do |car|
	pricesPerCar[car['id']] = {pricePerDay: car['price_per_day'], pricePerKm: car['price_per_km']}
end

output = {rentals: []}
data['rentals'].each do |rental|
	distancePrice = pricesPerCar[rental['car_id']][:pricePerKm] * rental['distance']
	rentalDuration = Date.parse(rental['end_date']) - Date.parse(rental['start_date'])
	rentalDuration = rentalDuration.ceil + 1
	dayPrice = pricesPerCar[rental['car_id']][:pricePerDay] * rentalDuration
	output[:rentals] << {id: rental['id'], price: (dayPrice + distancePrice)}
end

jsonOutput = JSON.pretty_generate(output)
File.write('output.json', jsonOutput)