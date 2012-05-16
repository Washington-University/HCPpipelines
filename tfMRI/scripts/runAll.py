import sys, os


def main():
	#EDAT directory
	directory = sys.argv[1]
	#map directory
	dirList = os.listdir(directory)
	#exclusion list
	exclist = []
	
	#open exclusion list
	exclusion = open('exclusion.txt','r')
	allexc = exclusion.readlines()
	for session in allexc:
		exclist.append(session.rstrip())
	
	for session in dirList:
		if session in exclist:
			print ("Skipping " + str(session) +": Found in Exclusion List")
		else:
			print ("Running Session: "+str(session))
			#should execute python generateEVS.py EDATS/CP100**/ ../EVS/CP100**
			#remove old EV directories
			#cmd = "rm -rf " +str(directory)+ "../EVS/"+str(session)
			#os.system(cmd)
			#recreate directory
			#cmd = "mkdir "+str(directory)+"../EVS/"+str(session)
			#os.system(cmd)
			#create EV files in new directory
			cmd = "python generateEVS.py "+str(directory)+str(session)+"/resources/eprime_log/files/"+str(session)+"/"+" "+str(directory)+"../EVS/"+str(session)
			os.system(cmd + " > "+str(directory)+"../EVS/"+str(session)+"/log.txt")

if __name__ == "__main__":
	main()
