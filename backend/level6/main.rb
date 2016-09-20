require "json"
require "date"

# your code
dataFile = File.read('data.json')
data = JSON.parse(dataFile)

pricesPerCar = {}
data['cars'].each do |car|
	pricesPerCar[car['id']] = {pricePerDay: car['price_per_day'], pricePerKm: car['price_per_km']}
end

def calculateRentalPrices(rental, pricesPerCar)
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

	return {id: rental['id'], price: price,
		options: {deductible_reduction: deductibleReduction },
	 	commission: {insurance_fee: insuranceFee, assistance_fee: assistanceFee, drivy_fee: drivyFee}}
end

def calculateActionsForRental(rentalPrices)
	rentalActions = {id: rentalPrices[:id], actions: []}

	driverPayment = rentalPrices[:price] + rentalPrices[:options][:deductible_reduction]
	rentalActions[:actions] << {who: 'driver', type: driverPayment < 0 ? 'credit' : 'debit', amount: driverPayment.abs}
	ownerPayment = (rentalPrices[:price] * 0.7).ceil
	rentalActions[:actions] << {who: 'owner', type: ownerPayment < 0 ? 'debit' : 'credit', amount: ownerPayment.abs}
	insurancePayment = rentalPrices[:commission][:insurance_fee]
	rentalActions[:actions] << {who: 'insurance', type: insurancePayment < 0 ? 'debit' : 'credit', amount: insurancePayment.abs}
	assistancePayment = rentalPrices[:commission][:assistance_fee]
	rentalActions[:actions] << {who: 'assistance', type: assistancePayment < 0 ? 'debit' : 'credit', amount: assistancePayment.abs}
	drivyPayment = rentalPrices[:commission][:drivy_fee] + rentalPrices[:options][:deductible_reduction]
	rentalActions[:actions] << {who: 'drivy', type: drivyPayment < 0 ? 'debit' : 'credit', amount: drivyPayment.abs}

	return rentalActions
end

def calculateRentalsPrices(rentals, pricesPerCar, isModification=false)
	output = {rentals: []}
	rentals.each do |rental|
		rentalPrices = calculateRentalPrices(rental, pricesPerCar)
		if isModification
			rentalPrices[:rental_id] = rental['rental_id']
		end
		output[:rentals] << rentalPrices
	end
	return output
end

def calculateRentalsActions(rentalsPrices, isModification=false)
	output = isModification ? {rental_modifications: []} : {rentals: []}
	rentalsPrices.each do |rentalPrices|
		rentalActions = calculateActionsForRental(rentalPrices)
		if isModification
			rentalActions[:rental_id] = rentalPrices[:rental_id]
			output[:rental_modifications] << rentalActions
		else	
			output[:rentals] << rentalActions
		end
	end
	return output
end

def saveRentalsById(rentals)
	rentalsById = {}
	rentals.each do |rental|
		rentalsById[rental['id']] = rental
	end
	return rentalsById
end

rentalsById = saveRentalsById(data['rentals'])
initialRentalsPrices = calculateRentalsPrices(data['rentals'], pricesPerCar)
initialRentals = calculateRentalsActions(initialRentalsPrices[:rentals])

rentalWithModifications = []
data['rental_modifications'].each do |rentalModification|
	rental = rentalsById[rentalModification['rental_id']]
	rentalWithModification = rental.clone

	rentalModification.keys.each do |key|
		rentalWithModification[key] = rentalModification[key]
	end

	rentalWithModifications << rentalWithModification
end

modificationRentalsPrices = calculateRentalsPrices(rentalWithModifications, pricesPerCar, true)

#Calculate the difference
modificationRentalsPrices[:rentals].each do |modificationRentalPrices|
	rentalId = modificationRentalPrices[:rental_id]
	initialRentalPrices = initialRentalsPrices[:rentals].select {|rental| rental[:id] == rentalId}.first
	modificationRentalPrices[:price] -= initialRentalPrices[:price]
	modificationRentalPrices[:options][:deductible_reduction] -= initialRentalPrices[:options][:deductible_reduction]
	modificationRentalPrices[:commission][:assistance_fee] -= initialRentalPrices[:commission][:assistance_fee]
	modificationRentalPrices[:commission][:insurance_fee] -= initialRentalPrices[:commission][:insurance_fee]
	modificationRentalPrices[:commission][:drivy_fee] -= initialRentalPrices[:commission][:drivy_fee]
end

output = calculateRentalsActions(modificationRentalsPrices[:rentals], true)


jsonOutput = JSON.pretty_generate(output)
File.write('output.json', jsonOutput)