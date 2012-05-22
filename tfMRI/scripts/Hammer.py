import sys, os

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check for consistency with task
	if openfile.find("HAMMER")!= -1 or openfile.find('Hammer')!= -1:
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
		Stim_Onset = []
		Stim_ACC = []
		Stim_RT = []
		Sync_Onset = []
		Sync_Val = False
		ACC = [ [], [] ]
		RT = [ [], [] ]
		Curr_Block = None
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "StimSlide.OnsetTime[Block]" or num_columns[i] == "StimSlide.OnsetTime":
				Stim_Onset_Index = i
			elif num_columns[i] == "StimSlide.ACC[Block]" or num_columns[i] == "StimSlide.ACC":
				Stim_ACC_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "StimSlide.RT" or num_columns[i] == "StimSlide.RT[Block]":
				RT_Index = i
			
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/neut.txt','w')
		EV2 = open(str(sys.argv[2]) + '/fear.txt','w')
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
		
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == Stim_Onset_Index:
					Stim_Onset.append(tempdata[j])
				elif j == Stim_ACC_Index:
					Stim_ACC.append(tempdata[j])
				elif j == SO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RT_Index:
					Stim_RT.append(tempdata[j])
		
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
			if Proc_Block[i] == "TrialsPROC":
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
				
					#check if you're trial or fix
					if Proc_Block[First_Index] == "TrialsPROC":
						#you're in a trial - grab onset
						First_Onset = int(Stim_Onset[First_Index])/1000.0
						print ("First Onset set to " + str(First_Onset))
					elif Proc_Block[First_Index] == "ShapesPromptPROC" or Proc_Block[First_Index] == "FacePromptPROC":
						#you're in a fix block - grab fix_onset
						print ("First Onset could not be defined")
			
				#if you're in a trial
				if Proc_Block[i] == "TrialsPROC":
					Stim_Onset_Val = int(Stim_Onset[i])/1000.0 - Sync_Val
					#test if block is faces or shapes
					if Proc_Block[i-1] == "FacePromptPROC":
						EV2.write(str(Stim_Onset_Val)+"	"+"18"+"	"+"1"+"\n")
						Curr_Block = "Faces"
					
					elif Proc_Block[i-1] == "ShapePromptPROC":
						EV1.write(str(Stim_Onset_Val)+"	"+"18"+"	"+"1"+"\n")
						Curr_Block = "Shapes"
				
					if Curr_Block == "Faces":
						if Stim_ACC[i] != "":
							ACC[0].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1" and Stim_RT[i] != "":
							RT[0].append(float(Stim_RT[i]))
					elif Curr_Block == "Shapes":
						if Stim_ACC[i] != "":
							ACC[1].append(float(Stim_ACC[i]))
						if Stim_ACC[i] == "1" and Stim_RT[i] != "":
							RT[1].append(float(Stim_RT[i]))
					
		for i in range(0,2):
			try:
				RT[i] = sum(RT[i])/float(len(RT[i]))
			except ZeroDivisionError:
				print ("WARNING ZeroDivisionError")
				RT[i] = -555
			try:
				ACC[i] = sum(ACC[i])/float(len(ACC[i]))
			except ZeroDivisionError:
				print ("WARNING ZeroDivisionError")
				ACC[i] = -555
				
		for i in range(len(RT)):
			if RT[i] == 0 or RT[i] == '0':
				RT[i] = -555
		
		Stats.write("Face Accuracy: " + str(ACC[0])+"\n")
		Stats.write("Shape Accuracy: " + str(ACC[1])+"\n")
		Stats.write("================"+"\n")
		Stats.write("Median Face RT: " + str(RT[0])+"\n")
		Stats.write("Median Shape RT: " + str(RT[1])+"\n")
	
	
		EV1.close()
		EV2.close()
		Stats.close()
		Sync_Txt.close()
		
	else:
		print ("File input not consistent with task.")
	
if __name__ == "__main__":
	main()