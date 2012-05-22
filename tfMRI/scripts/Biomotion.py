import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check if filename is consistent with task
	if openfile.find("BIOMOTION") != -1:
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
	
	
		Proc_Block = [] #16 #index starts at 0
		Vid1_Onset = [] #31
		Vid2_Onset = [] #34
		Vid3_Onset = [] #37
		Fix_Onset = [] #40
		Trial1Vid = [] #24
		Trial2Vid = [] #25
		Trial3Vid = [] #29
		Sync_Onset = []
		Sync_Val = False
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "Dot2Vid1.OnsetTime[Block]" or num_columns[i] == "Dot2Vid1.OnsetTime":
				 Vid1_Index = i
			elif num_columns[i] == "Dot2Vid2.OnsetTime[Block]" or num_columns[i] == "Dot2Vid2.OnsetTime":
				 Vid2_Index = i
			elif num_columns[i] == "Dot2Vid3.OnsetTime":
				 Vid3_Index = i
			elif num_columns[i] == "FifteenSecFix.OnsetTime":
				 Fix_Index = i
			elif num_columns[i] == "Trial1Vid[Block]" or num_columns[i] == "Trial1Vid":
				 T1V_Index = i
			elif num_columns[i] == "Trial2Vid[Block]" or num_columns[i] == "Trial2Vid":
				 T2V_Index = i
			elif num_columns[i] == "Trial3Vid":
				 T3V_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SO_Index = i
			
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/biomot.txt','w')
		EV2 = open(str(sys.argv[2]) + '/fix.txt','w')
		EV3 = open(str(sys.argv[2]) + '/rndmot.txt','w')
		Sync_Txt = open(str(sys.argv[2])+'/Sync.txt','w')
		
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == Vid1_Index:
					Vid1_Onset.append(tempdata[j])
				elif j == Vid2_Index:
					Vid2_Onset.append(tempdata[j])
				elif j == Vid3_Index:
					Vid3_Onset.append(tempdata[j])
				elif j == Fix_Index:
					Fix_Onset.append(tempdata[j])	
				elif j == T1V_Index:
					Trial1Vid.append(tempdata[j])
				elif j == T2V_Index:
					Trial2Vid.append(tempdata[j])
				elif j == T3V_Index:
					Trial3Vid.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
	
		#Consruct out EV's based on these data
		#set set first index arbitrarily high
		First_Index = 9999
		First_Onset = 0000
	
		#iterate through all blocks
		for i in range(len(Proc_Block)):
			#check to see if you're in the task
		
			if Proc_Block[i] == "TRSyncPROC" and Sync_Val == False:
				Sync_Val = int(Sync_Onset[i])/1000.0
				print "Sync Onset set to: " + str(Sync_Val)
				Sync_Txt.write(str(Sync_Val))
		
			if Proc_Block[i] == "TrialPROC" or Proc_Block[i] == "FifteenSecFixPROC":
				#check to see what trial you're in
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
				
					#check if you're trial or fix
					if Proc_Block[First_Index] == "TrialPROC":
						#you're in a trial - grab vid1 onset
						First_Onset = int(Vid1_Onset[First_Index])/1000.0
						print "First Onset set to " + str(First_Onset)
					elif Proc_Block[First_Index] == "FifteenSecFixPROC":
						#you're in a fix block - grab fix_onset
						First_Onset = int(Fix_Onset[First_Index])/1000.0
						print "First Onset set to " + str(First_Onset)
							
				#if you're in a fixation
				if Proc_Block[i] == "FifteenSecFixPROC":
					Fix_Onset_Val = int(Fix_Onset[i])/1000.0 - Sync_Val
					EV2.write(str(Fix_Onset_Val)+"	"+"15"+"	"+"1"+"\n")
				#if you're in a trial
				elif Proc_Block[i] == "TrialPROC" and Vid1_Onset[i] != '' or Vid2_Onset[i] != '' or Vid3_Onset[i] != '':
					Vid1_Onset_Val = int(Vid1_Onset[i])/1000.0 - Sync_Val
					Vid2_Onset_Val = int(Vid2_Onset[i])/1000.0 - Sync_Val
					Vid3_Onset_Val = int(Vid3_Onset[i])/1000.0 - Sync_Val
					#test if video files are random or named
					if Trial1Vid[i][0:4] == 'rand':
						#this block is random
						EV3.write(str(Vid1_Onset_Val)+"	"+"15"+"	"+"1"+"\n")
					else:
						#this block is named (biological motion)
						EV1.write(str(Vid1_Onset_Val)+"	"+"15"+"	"+"1"+"\n")
	
	
		EV1.close()
		EV2.close()
		EV3.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")
		
if __name__ == "__main__":
	main()