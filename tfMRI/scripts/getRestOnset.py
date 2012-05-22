import sys, os

def main():
	
	#catch filename, and its an edat
	openfile = sys.argv[1]
	#attempt to open for reading
	tabfile = open(openfile, 'r')
	#get the length of the first line to establish # of columns
	num_columns = tabfile.readline()
	#split by tabs to sort into a list
	num_columns = num_columns.split("\t")
	#len of the list is the number of columns
	num_columns_len = len(num_columns)
	#save all remaining data to a list
	data = tabfile.readlines()
	
	#open lists
	FeelFreeToRest = []
	Proc_Block = []
	Sync_Onset = []
	Sync_Val = False
	
	#Auto-detect column numbers
	for i in range(num_columns_len):
		if num_columns[i] == "FeelFreeToRest.OnsetTime":
			FFTR_Index = i
			
	try:
		FFTR_Index is int
	except UnboundLocalError:
		FFTR_Index = 9999
		
	
	#iterate through the data and grab onset times
	if FFTR_Index != 9999:
		for i in range(len(data)):
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)):
				#grab FFTR
				if j == FFTR_Index:
					#append it to the list
					FeelFreeToRest.append(tempdata[j])
					
		#print feelfreetorest onset in seconds to be captured by generateEVS
		print (float(FeelFreeToRest[0])/1000.0)
	
	else:
		print ("Feel Free To Rest Not Found")
		
if __name__ == "__main__":
	main()