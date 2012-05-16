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
		Manual_ACC = [ [], [], [], [] ] #NV, Syn, Sem, Prag
		RT = [ [], [], [], [] ]
		Manual_RT = [ [], [], [], [] ]
	
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
			elif num_columns[i] == "Control_Trials_Accuracy":
				ConTA_Index = i
			elif num_columns[i] == "Syntactic_Trials_Accuracy":
				SynTA_Index = i
			elif num_columns[i] == "Pragmatic_Trials_Accuracy":
				PragTA_Index = i
			elif num_columns[i] == "Semantic_Trials_Accuracy":
				SemTA_Index = i
			elif num_columns[i] == "Control_Trials_Avg_RT":
				ConTRT_Index = i
			elif num_columns[i] == "Syntactic_Trials_Avg_RT":
				SynTRT_Index = i
			elif num_columns[i] == "Pragmatic_Trials_Avg_RT":
				PragTRT_Index = i
			elif num_columns[i] == "Semantic_Trials_Avg_RT":
				SemTRT_Index = i
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/sem.txt','w')
		EV2 = open(str(sys.argv[2]) + '/syn.txt','w')
		EV3 = open(str(sys.argv[2]) + '/prag.txt','w')
		EV4 = open(str(sys.argv[2]) + '/ctrl.txt','w')
		EV5 = open(str(sys.argv[2]) + '/sem_rt.txt','w')
		EV6 = open(str(sys.argv[2]) + '/syn_rt.txt','w')
		EV7 = open(str(sys.argv[2]) + '/prag_rt.txt','w')
		EV8 = open(str(sys.argv[2]) + '/ctrl_rt.txt','w')
	
		EV9 = open(str(sys.argv[2]) + '/ctrl_cor.txt','w')
		EV10 = open(str(sys.argv[2]) + '/sem_cor.txt','w')
		EV11 = open(str(sys.argv[2]) + '/syn_cor.txt','w')
		EV12 = open(str(sys.argv[2]) + '/prag_cor.txt','w')
		EV13 = open(str(sys.argv[2]) + '/err.txt','w')
	
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
				elif j == ConTA_Index:
					ACC[0] = tempdata[j]
				elif j == SynTA_Index:
					ACC[1] = tempdata[j]
				elif j == PragTA_Index:
					ACC[3] = tempdata[j]
				elif j == SemTA_Index:
					ACC[2] = tempdata[j]
				elif j == ConTRT_Index:
					RT[0] = tempdata[j]
				elif j == SynTRT_Index:
					RT[1] = tempdata[j]
				elif j == PragTRT_Index:
					RT[3] = tempdata[j]
				elif j == SemTRT_Index:
					RT[2] = tempdata[j]
					
								
		for i in range(len(Proc_Trial)):
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
		
			if Proc_Block[i] == "TrialsPROC" and Proc_Block[i-1] == "TRSyncPROC":
				#you are in a trial
				#set first index
				First_Index = i
				First_Onset = SentenceStim_OnsetTime[i]
	#			print "First Onset set to: " + str(int(First_Onset)/1000.0)
			
			if Proc_Trial[i] == "TrialPROC" and SentenceStim_OnsetTime[i] != "":
				#set onset
				Onset_Time_Sec = int(SentenceStim_OnsetTime[i])/1000.0 - Sync_Val
				RT_Time_Sec = int(Stim_RT[i])
						
				if SentenceType[i] == "control":
					EV4.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					EV8.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					Manual_ACC[0].append(Response_ACC[i])
					if Response_ACC[i] == "1":
						EV9.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						Manual_RT[0].append(Stim_RT[i])
					else:
						EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				elif SentenceType[i] == "pragmatic":
					EV3.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					EV7.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					Manual_ACC[3].append(Stim_RT[i])
					if Response_ACC[i] == "1":
						EV12.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						Manual_RT[3].append(Stim_RT[i])
					else:
						EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				elif SentenceType[i] == "semantic":
					EV1.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					EV5.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					Manual_ACC[2].append(Stim_RT[i])
					if Response_ACC[i] == "1":
						EV10.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						Manual_RT[2].append(Stim_RT[i])
					else:
						EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
				elif SentenceType[i] == "syntactic":
					EV2.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
					EV6.write(str(Onset_Time_Sec)+"	"+"7"+"	"+str(RT_Time_Sec)+"\n")
					Manual_ACC[1].append(Stim_RT[i])
					if Response_ACC[i] == "1":
						EV11.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						Manual_RT[1].append(Stim_RT[i])
					else:
						EV13.write(str(Onset_Time_Sec)+"	"+"7"+"	"+"1"+"\n")
						
						
		for i in range(len(RT)):
			if RT[i][0] == "":
				try:
					RT[i] = float(sum(Manual_RT[i])/len(Manual_RT))
				except ZeroDivisionError:
					print("WARNING: ZeroDivisionError")
					RT[i] = -555
			if ACC[i][0] == "":
				try:
					ACC[i] = float(sum(Manual_ACC[i])/len(Manual_ACC))
				except ZeroDivisionError:
					print("WARNING: ZeroDivisionError")
					RT[i] = -555
				
		#Compute Stats
		NV_ACC = float(ACC[0])
		SYN_ACC = float(ACC[1])
		SEM_ACC = float(ACC[2])
		PRAG_ACC = float(ACC[3])
	
		NV_RT = float(RT[0])
		SYN_RT = float(RT[1])
		SEM_RT = float(RT[2])
		PRAG_RT = float(RT[3])
		
		for i in range(len(RT)):
			if RT[i][0] == "0":
				if i == 0:
					NV_RT = -555
				if i == 1:
					SYN_RT = -555
				if i == 2:
					SEM_RT = -555
				if i == 3:
					PRAG_RT = -555
	
		#Write out stats
		Stats.write("No Violoation ACC: " + str(NV_ACC)+"\n")
		Stats.write("No Violation Mean RT: " + str(NV_RT)+"\n")
		Stats.write("Pragmatic ACC: " + str(PRAG_ACC)+"\n")
		Stats.write("Pragmatic Mean RT: " + str(PRAG_RT)+"\n")
		Stats.write("Semantic ACC: " + str(SEM_ACC)+"\n")
		Stats.write("Semantic Mean RT: " + str(SEM_RT)+"\n")
		Stats.write("Syntactic ACC: " + str(SYN_ACC)+"\n")
		Stats.write("Syntactic Mean RT: " + str(SYN_RT)+"\n")
	
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
		EV5.close()
		EV6.close()
		EV7.close()
		EV8.close()
	
		EV9.close()
		EV10.close()
		EV11.close()
		EV12.close()
		EV13.close()
	
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")	
	
if __name__ == "__main__":
	main()