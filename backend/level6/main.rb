require "json"
require "date"

class Car
	attr_accessor :id, :price_per_day, :price_per_km

	def initialize(id, price_per_day, price_per_km)
		@id = id
		@price_per_day = price_per_day
		@price_per_km = price_per_km
	end
end

class Rental
	attr_accessor :id, :car, :start_date, :end_date, :distance, :deductible_reduction_active
	attr_reader :price, :assistance_fee, :insurance_fee, :drivy_fee, :deductible_reduction
	attr_reader :driver_payment, :owner_payment, :insurance_payment, :assistance_payment, :drivy_payment

	def initialize(id, car, start_date, end_date, distance, deductible_reduction_active = false)
		@id = id
		@car = car
		@start_date = start_date
		@end_date = end_date
		@distance = distance
		@deductible_reduction_active = deductible_reduction_active
	end

	def calculatePrices
		distance_price = @car.price_per_km * @distance
		rental_duration = Date.parse(@end_date) - Date.parse(@start_date)
		rental_duration = rental_duration.ceil + 1

		if rental_duration > 10
			day_price = ((rental_duration - 10) * 0.5 + 6 * 0.7 + 3 * 0.9 + 1) * @car.price_per_day
		elsif rental_duration > 4
			day_price = ((rental_duration - 4) * 0.3 + 3 * 0.9 + 1) * @car.price_per_day
		elsif rental_duration > 1
			day_price = ((rental_duration - 1) * 0.9 + 1) * @car.price_per_day
		else
			day_price = @car.price_per_day
		end
				
		day_price = day_price.ceil
		@price = day_price + distance_price
		commission = (price * 0.3).ceil
		
		@insurance_fee = (commission * 0.5).ceil
		@assistance_fee = rental_duration * 100
		@drivy_fee = commission - insurance_fee - assistance_fee
		@deductible_reduction = @deductible_reduction_active ? 400 * rental_duration : 0
	end

	def calculateActions
		if !@price
			calculatePrices
		end

		@driver_payment = @price + @deductible_reduction
		@owner_payment = (@price * 0.7).ceil
		@insurance_payment = @insurance_fee
		@assistance_payment = @assistance_fee
		@drivy_payment = @drivy_fee + @deductible_reduction
	end

	def outputPrices
		if !@price
			calculatePrices
		end

		output = {id: @id, price: @price,
		 	options: {deductible_reduction: @deductible_reduction},
			commission: {insurance_fee: @insurance_fee, assistance_fee: @assistance_fee, drivy_fee: @drivy_fee}}
		
		return output
	end

	def outputActions
		if !@driver_payment
			calculateActions
		end

		output = {id: @id, actions: []}
		output[:actions] << {who: 'driver', type: @driver_payment < 0 ? 'credit' : 'debit', amount: @driver_payment.abs}
		output[:actions] << {who: 'owner', type: @owner_payment < 0 ? 'debit' : 'credit', amount: @owner_payment.abs}
		output[:actions] << {who: 'insurance', type: @insurance_payment < 0 ? 'debit' : 'credit', amount: @insurance_payment.abs}
		output[:actions] << {who: 'assistance', type: @assistance_payment < 0 ? 'debit' : 'credit', amount: @assistance_payment.abs}
		output[:actions] << {who: 'drivy', type: @drivy_payment < 0 ? 'debit' : 'credit', amount: @drivy_payment.abs}
	
		return output
	end
end

class RentalModification < Rental
	attr_accessor :rental

	def initialize(id, rental, start_date = nil, end_date = nil, distance = nil)
		@id = id
		@rental = rental

		@start_date = start_date ? start_date : @rental.start_date
		@end_date = end_date ? end_date : @rental.end_date
		@distance = distance ? distance : @rental.distance
		@car = @rental.car
		@deductible_reduction_active = @rental.deductible_reduction_active
	end

	def calculatePrices
		if !@rental.price
			@rental.calculatePrices
		end

		method(:calculatePrices).super_method.call
		@price -= @rental.price
		@assistance_fee -= @rental.assistance_fee
		@insurance_fee -= @rental.insurance_fee
		@drivy_fee -=@rental.drivy_fee
		@deductible_reduction -= @rental.deductible_reduction
	end

	def calculateActions
		if !@price
			calculatePrices
		end

		method(:calculateActions).super_method.call
	end

	def outputPrices
		output = method(:outputPrices).super_method.call
		output['rental_id'] = @rental.id
		return output
	end

	def outputActions
		if !@driver_payment
			calculateActions
		end

		output = method(:outputActions).super_method.call
		output['rental_id'] = @rental.id
		return output
	end
end

dataFile = File.read('data.json')
data = JSON.parse(dataFile)

#Import the data
carsHash = {}
data['cars'].each do |car|
	carsHash[car['id']] = Car.new(car['id'], car['price_per_day'], car['price_per_km'])
end

rentalsHash = {}
data['rentals'].each do |rental|
	car = carsHash[rental['car_id']]
	rentalsHash[rental['id']] = Rental.new(rental['id'], car, rental['start_date'], rental['end_date'], rental['distance'], rental['deductible_reduction'])
end

rentalsModificationHash = {}
data['rental_modifications'].each do |rental_modification|
	rental = rentalsHash[rental_modification['rental_id']]
	rentalsModificationHash[rental_modification['id']] = RentalModification.new(rental_modification['id'], rental, rental_modification['start_date'],
																			 rental_modification['end_date'], rental_modification['distance'])
end


output = {rental_modifications: []}
rentalsModificationHash.each do |id, rental_modification|
	output[:rental_modifications] << rental_modification.outputActions
end

jsonOutput = JSON.pretty_generate(output)
File.write('output.json', jsonOutput)