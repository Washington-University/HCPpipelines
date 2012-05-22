import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("IAPS") != -1:
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
		TrialType = []
		Stim_Onset = []
		Stim_ACC = []
		BlockType = []
		Sync_Onset = []
		Sync_Val = False
		Neg_Neg = []
		Neg_Neut = []
		total = 0.0
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "TrialType":
				TT_Index = i
			elif num_columns[i] == "Stim.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "Stim.ACC":
				SA_Index = i
			elif num_columns[i] == "BlockType":
				BT_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SYO_Index = i
			
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/neg.txt','w')
		EV2 = open(str(sys.argv[2]) + '/neut.txt','w')
		EV3 = open(str(sys.argv[2]) + '/neg_event.txt','w') 
		EV4 = open(str(sys.argv[2]) + '/neut_event.txt','w')
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
		
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == TT_Index:
					TrialType.append(tempdata[j])
				elif j == SO_Index:
					Stim_Onset.append(tempdata[j])
				elif j == SA_Index:
					Stim_ACC.append(tempdata[j])
				elif j == BT_Index:
					BlockType.append(tempdata[j])
				elif j == SYO_Index:
					Sync_Onset.append(tempdata[j])
	
	
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		First_Onset = 0000
		#iterate through all blocks
		for i in range(len(Proc_Block)):
		
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				Sync_Txt.write(str(Sync_Val))
		
			#check to see if you're in the task
			if Proc_Block[i] == "RunPROC" or Proc_Block[i] == "FixationPROC":
				#check to see what trial you're in
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
				
					#check if you're trial or fix
					if Proc_Block[First_Index] == "RunPROC":
						#you're in a trial - grab vid1 onset
						First_Onset = int(Stim_Onset[First_Index])/1000.0
						print "First Onset set to " + str(First_Onset)
					elif Proc_Block[First_Index] == "FixationPROC":
						#you're in a fix block - grab fix_onset
						print "First Onset could not be defined for fixation"
			
				#if you're in a trial
				if Proc_Block[i] == "RunPROC":
					total = total + 1.0
					Stim_Onset_Val = int(Stim_Onset[i])/1000.0 - Sync_Val
					#test if block is mostlynegative or mostlyneutral
					if BlockType[i] == "MostlyNegative" and BlockType[i-1] == "":
						EV1.write(str(Stim_Onset_Val)+"	"+"20"+"	"+"1"+"\n")
					elif BlockType[i] == "MostlyNeutral" and BlockType[i-1] == "":
						EV2.write(str(Stim_Onset_Val)+"	"+"20"+"	"+"1"+"\n")
			
					if TrialType[i] == "Negative":		
						EV3.write(str(Stim_Onset_Val)+"	"+"2.5"+"	"+"1"+"\n")
						if Stim_ACC[i] == "1":
							Neg_Neg.append(1.0)
					elif TrialType[i] == "Neutral":
						EV4.write(str(Stim_Onset_Val)+"	"+"2.5"+"	"+"1"+"\n")
						if Stim_ACC[i] == "0":
							Neg_Neut.append(1.0)
	
		try:
			Neg_Neut_Perc = sum(Neg_Neut)/float(total)
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Neg_Neut_Perc = -555
			
		try:
			Neg_Neg_Perc = sum(Neg_Neg)/float(total)
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Neg_Neg_Perc = -555
	
		Stats.write("Percent Negative rated as Negative: " + str(Neg_Neg_Perc)+"\n")
		Stats.write("Percent Neutral rated as Negative: " + str(Neg_Neut_Perc)+"\n")
	
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