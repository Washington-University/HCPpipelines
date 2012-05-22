import sys, os

def main():
	#initialize variables
	total_read = []
	total_empty = []
	cluster_list = []
	
	#get <task>.feat directry
	directory = sys.argv[1]
	#split the directory to get the current task & subject
	directory_split = directory.split("/")
	subject = directory_split[3]
	task = directory_split[4]
	task = task.strip('.feat')
	#check that it is passed a feat directory
	if directory[-6:] == ".feat/":
	#	list the files in the directory
		dirlist = os.listdir(directory)
		#build a list of only cluster_zstat files
		for item in dirlist:
			#check for _std.txt first
			if item[-7:] == "std.txt":
				#ignore them
				pass
			#get only non _std.txt
			elif item[-4:] == ".txt":
				if item.find("cluster_zstat") != -1:
					cluster_list.append(item)
		#iterate through the list
		for cluster in cluster_list:	
			#open each cluster text file
			curr_file = open(directory+"/"+cluster,'r')
			total_read.append(1.0)
			#grab data with readlines, each line is a str in a list
			data = curr_file.readlines()
			#if length of list is 1, then the text file was empty, count it
			if len(data) == 1:
				total_empty.append(1.0)
		#print number of empty out of number read in (will be captured by Sachin Lev2)
		print (str(task))
		print ("Found "+str(sum(total_empty))+" of "+str(sum(total_read))+" Zstats empty.")
		
	else:
		print ("Given incorrect directory, please pass only .feat directories.")
	
if __name__ == "__main__":
	main()