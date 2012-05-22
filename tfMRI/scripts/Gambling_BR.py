import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("GAMB_BLOCKED") != -1:
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
	
		Proc_Block = [] #19
		Proc_Trial = [] #29
		Block_Type = []
		Trial_Type = [] #38
		QM_Onset = [] #42
		Sync_Onset = []
		Sync_Val = False
		QM_RT = []
		RT = []
		Total_Responses = 0.0
		NLR = []
		NLR_Total = 0.0
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "Procedure[Trial]":
				PT_Index = i
			elif num_columns[i] == "TrialType":
				TT_Index = i
			elif num_columns[i] == "QuestionMark.OnsetTime":
				QM_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "QuestionMark.RT":
				RT_Index = i
	
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/win.txt','w')
		EV2 = open(str(sys.argv[2]) + '/loss.txt','w')
		EV3 = open(str(sys.argv[2]) + '/neut.txt','w') 
		EV4 = open(str(sys.argv[2]) + '/win_event.txt','w')
		EV5 = open(str(sys.argv[2]) + '/loss_event.txt','w')
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2])+'/Sync.txt','w')
	
		for i in range(len(data)):
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == PT_Index:
					Proc_Trial.append(tempdata[j])
				elif j == TT_Index:
					Trial_Type.append(tempdata[j])
				elif j == QM_Index:
					QM_Onset.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					QM_RT.append(tempdata[j])
	
		#Recreate Block_Type field
		#set local holder variables to zero
		Neutral_Count = 0
		Punish_Count = 0
		Reward_Count = 0
		Total_Trials = 0
		Curr_Block = ''
	
		#step through all Trials
		for i in range(len(Proc_Block)):
			#if trial type is reward - add a counter
			if Trial_Type[i] == "Reward":
				Reward_Count = Reward_Count + 1
				Total_Trials = Total_Trials + 1
			#if trial type is punish - add a counter
			elif Trial_Type[i] == "Punishment":
				Punish_Count = Punish_Count + 1
				Total_Trials = Total_Trials + 1
			#if trial type is neutral - add to counter
			elif Trial_Type[i] == "Neutral":
				Neutral_Count = Neutral_Count + 1
				Total_Trials = Total_Trials + 1
			elif Trial_Type[i] == "" and Trial_Type[i-1] == "":
				Block_Type.append("")
			
			#once you've finished a block
			if Trial_Type[i] == "" and Trial_Type[i-1] != "":
				#check which count is higher
				if Reward_Count > Punish_Count:
					Curr_Block = "Reward"
					#print "Current block set to Reward"
				elif Punish_Count > Reward_Count:
					Curr_Block = "Punishment"
					#print "Current block set to Punishment"
				else:
					print "NO BLOCK TYPE ESTABLISHED FOR BLOCK:" + str(Run1List[i])
				
				for i in range(Total_Trials):
					#write out the block type
					Block_Type.append(Curr_Block)
				Block_Type.append("")
				
				#reset counters
				Neutral_Count = 0
				Punish_Count = 0
				Reward_Count = 0
				Total_Trials = 0
				Curr_Block = ''
											
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		First_Onset = 0000
		#iterate through all blocks
		for i in range(len(Proc_Trial)):
		
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				print "Sync Onset set to: " + str(Sync_Val)
				Sync_Txt.write(str(Sync_Val))
		
			#check to see if you're in the task
			if Proc_Trial[i] == "GamblingTrialPROC" or Proc_Trial[i] == "FixationBlockPROC":
				#check to see what trial you're in
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
					print "First Index set to: " + str(First_Index)
			
					First_Onset = float(QM_Onset[First_Index])/1000.0
					print "First Onset set to: " + str(First_Onset)
																			
				if Proc_Trial[i] == "GamblingTrialPROC":
					if Proc_Trial[i-1] == "FixationBlockPROC" or Proc_Trial[i-1] == "InitialTR":
						QM_Onset_Sec = float(QM_Onset[i])/1000.0 - float(Sync_Val)
						#check block type
						if Block_Type[i] == "Reward":
							EV1.write(str(QM_Onset_Sec) + "	" + "28.0" + "	" + "1" + "\n")
						elif Block_Type[i] == "Punishment":
							EV2.write(str(QM_Onset_Sec) + "	" + "28.0" + "	" + "1" + "\n")
						else:
							continue
							#print "Error: Block Type out of bounds"
					QM_Onset_Sec = float(QM_Onset[i])/1000.0 - float(Sync_Val)
					if Trial_Type[i] == "Neutral":
						EV3.write(str(QM_Onset_Sec) + "	" + "3.5" + "	" + "1" + "\n")
					elif Trial_Type[i] == "Reward":
						EV4.write(str(QM_Onset_Sec) + "	" + "3.5" + "	" + "1" + "\n")
					elif Trial_Type[i] == "Punishment":
						EV5.write(str(QM_Onset_Sec) + "	" + "3.5" + "	" + "1" + "\n")
				
					if QM_RT[i] != '0' and QM_RT[i] != '':
						RT.append(float(QM_RT[i]))
					else:
						NLR.append(1.0)
					
					Total_Responses = Total_Responses + 1.0
		try:
			RT = sum(RT)/float(len(RT))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			RT = -555
			
		Num_NLR = sum(NLR)
		try:
			NLR_Total = (Num_NLR/float(Total_Responses))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			NLR_Total = -555
			
		try:	
			NLR_ACC = 1.0 - (Num_NLR/float(Total_Responses))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			NLR_ACC = -555
	
		Stats.write("Mean RT: " + str(RT)+"\n")
		Stats.write("Percent NLR: " + str(NLR_Total) +"\n")
		Stats.write("NLR as ACC: " + str(NLR_ACC)+"\n")
	
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
		EV5.close()
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")	
				
if __name__ == "__main__":
	main()