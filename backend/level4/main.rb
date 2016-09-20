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

	pricePerDay = pricesPerCar[rental['car_id']][:pricePerDay]
	if rentalDuration > 10
		dayPrice = ((rentalDuration - 10) * 0.5 + 6 * 0.7 + 3 * 0.9 + 1) * pricePerDay
	elsif rentalDuration > 4
		dayPrice = ((rentalDuration - 4) * 0.3 + 3 * 0.9 + 1) * pricePerDay
	elsif rentalDuration > 1
		dayPrice = ((rentalDuration - 1) * 0.9 + 1) * pricePerDay
	else
		dayPrice = pricePerDay
	end
			
	dayPrice = dayPrice.ceil
	price = dayPrice + distancePrice
	commission = (price * 0.3).ceil
	insuranceFee = (commission * 0.5).ceil
	assistanceFee = rentalDuration * 100
	drivyFee = commission - insuranceFee - assistanceFee
	deductibleReduction = rental['deductible_reduction'] ? 400 * rentalDuration : 0

	output[:rentals] << {id: rental['id'], price: price,
		options: {deductible_reduction: deductibleReduction },
	 	commission: {insurance_fee: insuranceFee, assistance_fee: assistanceFee, drivy_fee: drivyFee}}
end

jsonOutput = JSON.pretty_generate(output)
File.write('output.json', jsonOutput)