import pymongo as pm
import numpy as np
import csv
import json
from sys import argv
from geopy import distance

def main(city):
	connection = pm.MongoClient()
	buffalo = connection.buffalo

	directory = "../../data/" + city + "/"

	#Streets.geojson			apjansingTest_crimes.csv	cameras.geojson			crimes.csv			police_districts.csv

	with open(directory+"cameras.geojson", 'r') as camerasData:
		camerasData = json.load(camerasData)
		print("Dropping Cameras...")
		buffalo.cameras.drop()
		print("Cameras dropped!")
		buffalo.cameras.create_index([("geometry",  "2dsphere")])
		print("Loading Cameras...")
		ingestGeoJsonFeatureToMongoDB(camerasData, buffalo.cameras)
		print("Cameras loaded!")


	with open(directory+"police_districts.geojson", 'r') as policeDistricts:
		policeDistricts = json.load(policeDistricts)
		print("Dropping Districts...")
		buffalo.districts.drop()
		print("Districts dropped!")
		buffalo.districts.create_index([("geometry", "2dsphere")])
		print("Loading Districts...")
		ingestGeoJsonFeatureToMongoDB(policeDistricts, buffalo.districts)
		print("Districts loaded!")
	
	with open(directory+"Streets.geojson", 'r') as streetsData:
		streetsData = json.load(streetsData)
		print("Dropping Streets...")
		buffalo.streets.drop()
		print("Streets dropped!")
		buffalo.streets.create_index([("geometry", "2dsphere")])
		print("Loading Streets...")
		ingestGeoJsonFeatureToMongoDB(streetsData, buffalo.streets)
		print("Streets loaded!")
		print("Updating Streets...")
		# Update each street with a length
		cursor = buffalo.streets.find()
		while cursor.alive:
			length = 0
			token = cursor.next()
			coords = token['geometry']['coordinates']
			for i in range(len(coords)):
				for j in range(len(coords[i])):
					for k in range(j+1, len(coords[i])):
						length += getLength(coords[i][j], coords[i][k])
			buffalo.streets.update_one( {"_id":token['_id']}, {"$set": { "streetLength": length }} )
		print("Streets updated!")
	
	
	'''
	['incident_id' 'case_number' 'incident_datetime' 'incident_type_primary'
	 'incident_description' 'clearance_type' 'address_1' 'address_2' 'city'
	 'state' 'zip' 'country' 'latitude' 'longitude' 'created_at' 'updated_at'
	 'location' 'hour_of_day' 'day_of_week' 'parent_incident_type']
	'''
	with open(directory+"apjansingTest_crimes.csv", 'r') as crimeData:
		CSV = np.array(list(csv.reader(crimeData, quotechar='"', delimiter=',')))
		print("Dropping Crimes...")
		buffalo.crimes.drop()
		print("Crimes dropped!")
		buffalo.crimes.create_index([("location", pm.GEO2D)])
		print("Loading Crimes...")
		keys = CSV[0]
		for i in range(1, len(CSV)):
			payload = getJson(keys, CSV[i])
			lon = payload['longitude']
			lat = payload['latitude']
			if lon == 0. and lat == 0.:
				continue			
			payload['location'] = str(lon) + ',' + str(lat)
			buffalo.crimes.insert_one(payload)
		print("Crimes loaded!")
		print("Updating Crimes...")
		cursor = buffalo.crimes.find()
		i = 0
		while cursor.alive:
			i += 1
			if i % 5000 == 0:
				print(i, " tokens processed...")
			token = cursor.next()
			loc = token['location'].split(',')
			loc[0] = float(loc[0])
			loc[1] = float(loc[1])
			near = {"geometry": {"$near": {"$geometry": {"type": "Point" ,"coordinates": loc } } } }
			near = buffalo.cameras.find(near).limit(1).next()
			nearLoc = near['geometry']['coordinates']
			closestCamera = distance.distance((nearLoc[1], nearLoc[0]), (loc[1], loc[0])).miles
			buffalo.crimes.update_one( {"_id":token['_id']}, {"$set": { "closestCamera": closestCamera }} )		
		print("Crimes updated!")


def ingestGeoJsonFeatureToMongoDB(geojson, collection):
	for feature in geojson['features']:
		collection.insert_one(feature)

def getJson(keys, values):
	payload = {}
	for i,j in zip(keys,values):
		try:
			payload[i] = float(j)
		except:
			payload[i] = j   
	return payload

'''
Knowing that you're receiving location points as (long, lat), because that is how
MongoDB deal with location points, and you need to swap them for this function.
'''
def getLength(loc1, loc2):
	return distance.distance((loc1[1], loc1[0]), (loc2[1], loc2[0])).miles

					

if __name__ == '__main__':
	cities = argv[1:]
	for city in cities:
		try:
			main(city)
		except:
			print("City, " + city + ", dataset not found.")