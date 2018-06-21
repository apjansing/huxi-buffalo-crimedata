import pymongo as pm
import numpy as np
import csv
import json
from geopy import distance

def main():
	connection = pm.MongoClient()
	buffalo = connection.buffalo

	directory = "../../data/"
	camerasData = readGeoJson(directory+"Buffalo Police Department Camera Locations.geojson")
	policeDistricts = readGeoJson(directory+"Police Districts.geojson")
	streetsData = readGeoJson(directory+"Streets.geojson")
	crimeData = readCSV(directory+"Crime_Incidents.csv")

	print("Dropping Cameras...")
	buffalo.cameras.drop()
	print("Cameras dropped!")
	buffalo.cameras.create_index([("geometry",  "2dsphere")])
	print("Loading Cameras...")
	ingestGeoJsonFeatureToMongoDB(camerasData, buffalo.cameras)
	print("Cameras loaded!")


	print("Dropping Districts...")
	buffalo.districts.drop()
	print("Districts dropped!")
	buffalo.districts.create_index([("geometry", "2dsphere")])
	print("Loading Districts...")
	ingestGeoJsonFeatureToMongoDB(policeDistricts, buffalo.districts)
	print("Districts loaded!")


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
	print("Dropping Crimes...")
	buffalo.crimes.drop()
	print("Crimes dropped!")
	buffalo.crimes.create_index([("location", pm.GEO2D)])
	print("Loading Crimes...")
	keys = crimeData[0]
	for i in range(1, len(crimeData)):
		payload = getJson(keys, crimeData[i])
		payload['location'] = str(payload['longitude']) + ',' + str(payload['latitude'] )
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


def readGeoJson(FILE_PATH):
	with open(FILE_PATH, 'r') as f:
		return json.load(f)

def ingestGeoJsonFeatureToMongoDB(geojson, collection):
	for feature in geojson['features']:
		collection.insert_one(feature)

def readCSV(FILE_PATH):
	CSV = []
	with open(FILE_PATH, 'r') as F:
		CSV = list(csv.reader(F, quotechar='"', delimiter=','))
	return np.array(CSV)

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
	main()