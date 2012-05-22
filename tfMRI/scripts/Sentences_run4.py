import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("SENT") != -1:
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
	
	
		Proc_Block = []
		Proc_Trial = []
		SentenceType = []
		SentenceStim_OnsetTime = []
		Response_ACC = []
		Stim_RT = []
		Response_OnsetTime = []
		Sync_Onset = []
		Sync_Val = False
		ACC = [ [], [], [], [] ] #NV, Syn, Sem, Prag
		RT = [ [], [], [], [] ]
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
			 	PB_Index = i
			elif num_columns[i] == "Procedure[Trial]":
				PT_Index = i
			elif num_columns[i] == "SentenceType":
				ST_Index = i
			elif num_columns[i] == "SentenceStim.OnsetTime":
			 	SO_Index = i
			elif num_columns[i] == "Response.ACC":
				RA_Index = i
			elif num_columns[i] == "Response.OnsetTime":
				RO_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SYO_Index = i
			elif num_columns[i] == "Stim.RT" or num_columns[i] == "Response.RT":
				RT_Index = i
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/sem.txt','w')
		EV2 = open(str(sys.argv[2]) + '/syn.txt','w')
		EV3 = open(str(sys.argv[2]) + '/prag.txt','w')
		EV4 = open(str(sys.argv[2]) + '/ctrl.txt','w')
		#EV5 = open(str(sys.argv[2]) + '/Semantic_RT.txt','w')
		#EV6 = open(str(sys.argv[2]) + '/Syntactic_RT.txt','w')
		#EV7 = open(str(sys.argv[2]) + '/Pragmatic_RT.txt','w')
		#EV8 = open(str(sys.argv[2]) + '/Control_RT.txt','w')
	
		#EV9 = open(str(sys.argv[2]) + '/Correct_Control.txt','w')
		#EV10 = open(str(sys.argv[2]) + '/Correct_Semantic.txt','w')
		#EV11 = open(str(sys.argv[2]) + '/Correct_Syntactic.txt','w')
		#EV12 = open(str(sys.argv[2]) + '/Correct_Pragmatic.txt','w')
		#EV13 = open(str(sys.argv[2]) + '/Error.txt','w')
	
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == PT_Index:
					Proc_Trial.append(tempdata[j])
				elif j == ST_Index:
					SentenceType.append(tempdata[j])
				elif j == SO_Index:
					SentenceStim_OnsetTime.append(tempdata[j])
				elif j == RA_Index:
					Response_ACC.append(tempdata[j])
				elif j == RO_Index:
					Response_OnsetTime.append(tempdata[j])
				elif j == SYO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					Stim_RT.append(tempdata[j])
									
		for i in range(len(Proc_Trial)):
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
		
			if Proc_Block[i] == "TrialsPROC" and Proc_Block[i-1] == "TRSyncPROC":
				#you are in a trial
				#set first index
				First_Index = i
				First_Onset = SentenceStim_OnsetTime[i]
				print "First Onset set to: " + str(int(First_Onset)/1000.0)
			
			if Proc_Trial[i] == "TrialPROC" and SentenceStim_OnsetTime[i] != "":
				#set onset
				Onset_Time_Sec = int(SentenceStim_OnsetTime[i])/1000.0 - Sync_Val
				RT_Time_Sec = int(Stim_RT[i])
						
				if SentenceType[i] == "control":
					EV4.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				#	EV8.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					if Response_ACC[i] == "0":
						RT[0].append(int(Stim_RT[i]))
						ACC[0].append(int(1.0))
					#	EV9.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					else:
					#	EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						ACC[0].append(int(0.0))
					
				elif SentenceType[i] == "pragmatic":
					EV3.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				#	EV7.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					if Response_ACC[i] == "0":
						RT[3].append(int(Stim_RT[i]))
						ACC[3].append(int(1.0))
						#EV12.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					else:
					#	EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						ACC[3].append(int(0.0))
					
				elif SentenceType[i] == "semantic":
					EV1.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				#	EV5.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					if Response_ACC[i] == "0":
						RT[2].append(int(Stim_RT[i]))
						ACC[2].append(int(1.0))
					#	EV10.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					else:
					#	EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						ACC[2].append(int(0.0))
					
				elif SentenceType[i] == "syntactic":
					EV2.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				#	EV6.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					if Response_ACC[i] == "0":
						RT[1].append(int(Stim_RT[i]))
						ACC[1].append(int(1.0))
				#		EV11.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					else:
					#	EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						ACC[1].append(int(0.0))
	
		#Compute Stats
		if len(ACC[0]) != 0:
			NV_ACC = sum(ACC[0])/float(len(ACC[0]))
		else:
			NV_ACC = -555
		if len(ACC[1]) != 0:
			SYN_ACC = sum(ACC[1])/float(len(ACC[1]))
		else:
			SYN_ACC = -555
		if len(ACC[2]) != 0:
			SEM_ACC = sum(ACC[2])/float(len(ACC[2]))
		else:
			SEM_ACC = -555
		if len(ACC[3]) != 0:
			PRAG_ACC = sum(ACC[3])/float(len(ACC[3]))
		else:
			PRAG_ACC = -555
	
		if len(RT[0]) != 0:
			NV_RT = sum(RT[0])/float(len(RT[0]))
		else:
			NV_RT = -555
		if len(RT[1]) != 0:
			SYN_RT = sum(RT[1])/float(len(RT[1]))
		else:
			SYN_RT = -555
		if len(RT[2]) != 0:
			SEM_RT =  sum(RT[2])/float(len(RT[2]))
		else:
			SEM_RT = -555
		if len(RT[3]) != 0:
			PRAG_RT =  sum(RT[3])/float(len(RT[3]))
		else:
			PRAG_RT = -555
	
		#Write out stats
		Stats.write("No Violoation ACC: -999" + "\n")
		Stats.write("No Violation Mean RT: -999" + "\n")
		Stats.write("Pragmatic ACC: -999" + "\n")
		Stats.write("Pragmatic Mean RT: -999" + "\n")
		Stats.write("Semantic ACC: -999" + "\n")
		Stats.write("Semantic Mean RT: -999" + "\n")
		Stats.write("Syntactic ACC: -999" + "\n")
		Stats.write("Syntactic Mean RT: -999" + "\n")
	
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
	#	EV5.close()
	#	EV6.close()
	#	EV7.close()
	#	EV8.close()
	#	
	#	EV9.close()
	#	EV10.close()
	#	EV11.close()
	#	EV12.close()
	#	EV13.close()
	
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")	
	
if __name__ == "__main__":
	main()