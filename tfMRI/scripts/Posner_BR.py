import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for task consistency
	if openfile.find("POS_BLOCKED") != -1:
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
		Validity = []
		BlockType = []
		Cue_Onset = []
		Target_Onset = []
		Resp_ACC = []
		Sync_Onset = []
		Sync_Val = False
		Stim_RT = []
		ACC = [ [], [] ]
		RT = [ [], [] ]
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
			 	PB_Index = i
			elif num_columns[i] == "Procedure[Trial]":
				PT_Index = i
			elif num_columns[i] == "Validity":
				Val_Index = i
			elif num_columns[i] == "BlockType":
			 	BT_Index = i
			elif num_columns[i] == "Cue.OnsetTime":
				CO_Index = i
			elif num_columns[i] == "Target.OnsetTime":
				TO_Index = i
			elif num_columns[i] == "Response.ACC" or num_columns[i] == "Target.ACC":
				RA_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime" or num_columns[i] == "CountDownSlide.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "Target.RT" or num_columns[i] == "Response.RT":
				RT_Index = i
						
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/val.txt','w')
		EV2 = open(str(sys.argv[2]) + '/inv.txt','w')
		EV3 = open(str(sys.argv[2]) + '/err.txt','w')
		EV4 = open(str(sys.argv[2]) + '/cue.txt','w')
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
				elif j == Val_Index:
					Validity.append(tempdata[j])
				elif j == BT_Index:
					BlockType.append(tempdata[j])
				elif j == CO_Index:
					Cue_Onset.append(tempdata[j])
				elif j == TO_Index:
					Target_Onset.append(tempdata[j])
				elif j == RA_Index:
					Resp_ACC.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					Stim_RT.append(tempdata[j])
	
	
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		First_Onset = 0000
		#iterate through all blocks
		
		for i in range(len(Proc_Trial)):
		
			if Proc_Block[i] == "SyncUp" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
						
			#check if in trial
			if Proc_Trial[i] == "TrialRunPROC" and Proc_Trial[i-1] == "CountDownPROC" or Proc_Trial[i-1] == "":
				#you are in a trial
				#set first index
				First_Index = i
				First_Onset = Target_Onset[i]
				print "First Onset set to: " + str(int(First_Onset)/1000.0)
			
			
			if Proc_Trial[i] == "TrialRunPROC" and Proc_Trial[i-1] == "FixationBlockPROC" or Proc_Trial[i-1] == "CountDownPROC" or Proc_Trial[i-1] == "":
				#set onset time			
				if Target_Onset[i] != "":
					Onset_Time_Sec = int(Target_Onset[i])/1000.0 - Sync_Val
					#check blocktype
					if BlockType[i] == "ValidBlock":
						EV1.write(str(Onset_Time_Sec)+"	"+"20"+"	"+"1"+"\n")
					elif BlockType[i] == "InvalidBlock":
						EV2.write(str(Onset_Time_Sec)+"	"+"20"+"	"+"1"+"\n")
					#check trialtype
					if Resp_ACC[i] == "0":
						EV3.write(str(Onset_Time_Sec)+"	"+"2.5"+"	"+"1"+"\n")
				
				
					Cue_Onset_Sec = int(Cue_Onset[i])/1000.0 - Sync_Val
					EV4.write(str(Onset_Time_Sec)+"	"+"1.0"+"	"+"1"+"\n")
			
			if Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Valid":
				ACC[0].append(int(Resp_ACC[i]))
			if Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Invalid":
				ACC[1].append(int(Resp_ACC[i]))
			
			if Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Valid" and Resp_ACC[i] == "1":
				RT[0].append(int(Stim_RT[i]))
			if Proc_Trial[i] == "TrialRunPROC" and Validity[i] == "Invalid" and Resp_ACC[i] == "1":
				RT[1].append(int(Stim_RT[i]))
			
			
		#Compute stats
		for i in range(len(ACC)):
			if len(ACC[i]) != 0:
				try:
					ACC[i] = sum(ACC[i])/float(len(ACC[i]))
				except ZeroDivisionError:
					print ("WARNING ZeroDivisionError")
					ACC[i] = -555
		
		for i in range(len(RT)):
			if ACC[i] == 0.0:
				RT[i] = 0.0
			elif len(RT[i]) != 0:
				try:
					RT[i] = sum(RT[i])/float(len(RT[i]))
				except ZeroDivisionError:
					print ("WARNING ZeroDivisionError")
					RT[i] == -555
			
		Stats.write("Accuracy on invalid trials: " + str(ACC[1])+"\n")
		Stats.write("Accuracy on valid trials: " + str(ACC[0])+"\n")
		Stats.write("=============="+"\n")
		Stats.write("Median RT to correct invalid trials: " + str(RT[1])+"\n")
		Stats.write("Median RT to correct valid trials: " + str(RT[0])+"\n")	
			
		EV1.close()
		EV2.close()
		EV3.close()
		EV4.close()
		Stats.close()
		Sync_Txt.close()
	
	else:
		print ("File input not consistent with task.")
	
if __name__ == "__main__":
	main()