import sys, os, datetime

def main():
	
	#catch filename
	openfile = sys.argv[1]
	#check filename for consistency with task
	if openfile.find("SOCIAL")!= -1 or openfile.find("Social")!= -1:
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
		Type_Block = []
		MovieDisplay1_Onset = []
		Sync_Onset = []
		ResponseSlide_Resp = []
		ResponseSlide_RT = []
		Per_Int = []
		Per_Unsure = []
		Per_Random = []
		NLR = []
		Total_Response = 0.0
		Resp_MeanRT = []
		Sync_Val = False
		date_check = False
		
		total_mental = 0.0
		total_random = 0.0
		keyed_mental = 0.0
		keyed_random = 0.0
		keyed_unsure = 0.0
		
		#set the date of the coding change
		change_date = datetime.date(2011,6,10)
	
		#Auto-detect column numbers
		for i in range(num_columns_len):
			if num_columns[i] == "Procedure[Block]":
				PB_Index = i
			elif num_columns[i] == "Type[Block]" or num_columns[i] == "Type":
				TB_Index = i
			elif num_columns[i] == "MovieDisplay1.OnsetTime[Block]" or num_columns[i] == "MovieDisplay1.OnsetTime":
				SO_Index = i
			elif num_columns[i] == "SyncSlide.OnsetTime":
				SYO_Index = i
			elif num_columns[i] == "ResponseSlide.RESP" or num_columns[i] == "ResponseSlide.RESP[Block]":
				RS_Index = i
			elif num_columns[i] == "ResponseSlide.RT" or num_columns[i] == "ResponseSlide.RT[Block]":
				RT_Index = i
			
		#create EV text files
		cmd = 'mkdir -p ' + str(sys.argv[2])
		os.system(cmd)
		EV1 = open(str(sys.argv[2]) + '/mental.txt','w')
		EV2 = open(str(sys.argv[2]) + '/rnd.txt','w')
		EV3 = open(str(sys.argv[2]) + '/mental_resp.txt','w')
		EV4 = open(str(sys.argv[2]) + '/other_resp.txt','w')
		Stats = open(str(sys.argv[2]) + '/Stats.txt','w')
		Sync_Txt = open(str(sys.argv[2]) + '/Sync.txt','w')
	
		for i in range(len(data)): 
			#split data[i] into list
			tempdata = data[i].split("\t")
			for j in range(len(tempdata)): #
				if j == PB_Index:
					Proc_Block.append(tempdata[j])
				elif j == TB_Index:
					Type_Block.append(tempdata[j])
				elif j == SO_Index:
					MovieDisplay1_Onset.append(tempdata[j])
				elif j == SYO_Index:
					Sync_Onset.append(tempdata[j])
				elif j == RS_Index:
					ResponseSlide_Resp.append(tempdata[j])
				elif j == RT_Index:
					ResponseSlide_RT.append(tempdata[j])
	
	
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
			if Proc_Block[i] == "TrialsPROC" or Proc_Block[i] == "FixationBlockPROC":
				#check to see what trial you're in
				#first index allows subtraction of time spent on practice
				if First_Index == 9999:
					First_Index = i
				
					#check if you're trial or fix
					if Proc_Block[First_Index] == "TrialsPROC":
						#you're in a trial - grab vid1 onset
						First_Onset = int(MovieDisplay1_Onset[First_Index])/1000.0
						print ("First Onset set to " + str(First_Onset))
					elif Proc_Block[First_Index] == "FixationBlockPROC":
						#you're in a fix block - grab fix_onset
						print ("First Onset could not be defined for fixation")
			
				#if you're in a trial
				if Proc_Block[i] == "TrialsPROC":
					#check the date
					if date_check == False:
						cmd = "cat " + openfile + " | grep ':' | awk '{print $2}' | tr ':' '.' | sort -u"
						os.system(cmd + " > tmp.txt")
						fp = open('tmp.txt')
						date = fp.readlines()[0].rstrip()
						date = date.split("-")
						date = datetime.date(int(date[2]),int(date[0]),int(date[1]))
							
					#elif the date is after june 10th 2011 - 2 = mental interaction
					if change_date < date:
						Movie_Onset_Val = int(MovieDisplay1_Onset[i])/1000.0 - Sync_Val
						#test if block is mostlynegative or mostlyneutral
						if Type_Block[i] == "Mental" and Type_Block[i-1] == "":
							EV1.write(str(Movie_Onset_Val)+"	"+"23"+"	"+"1"+"\n")
							total_mental = total_mental + 1.0
							if ResponseSlide_Resp[i] == "b":
								keyed_mental = keyed_mental + 1.0
								
						elif Type_Block[i] == "Random" and Type_Block[i-1] == "":
							EV2.write(str(Movie_Onset_Val)+"	"+"23"+"	"+"1"+"\n")
							total_random = total_random + 1.0
							if ResponseSlide_Resp[i] == "g":
								keyed_random = keyed_random + 1.0
								
						if ResponseSlide_Resp[i] != "":
							Resp_MeanRT.append(float(ResponseSlide_RT[i]))
								
						if ResponseSlide_Resp[i] == "b":
							EV3.write(str(Movie_Onset_Val)+"	"+"23"+"	"+"1"+"\n")
							Per_Int.append(1.0)
							Total_Response = Total_Response + 1.0
						elif ResponseSlide_Resp[i] == "y":
							EV4.write(str(Movie_Onset_Val)+"	"+"23"+"	"+"1"+"\n")
							Per_Unsure.append(1.0)
							keyed_unsure = keyed_unsure + 1.0
							Total_Response = Total_Response + 1.0
						elif ResponseSlide_Resp[i] == "g":
							EV4.write(str(Movie_Onset_Val)+"	"+"23"+"	"+"1"+"\n")
							Per_Random.append(1.0)
							Total_Response = Total_Response + 1.0
						else:
							NLR.append(1.0)
							Total_Response = Total_Response + 1.0
		
		Total_Answered = float(sum(Per_Int) + sum(Per_Unsure) + sum(Per_Random))
		
		
		try:
			NLR = float(sum(NLR)/Total_Response)
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			NLR = -555
			
		try:
			Resp_MeanRT = float(sum(Resp_MeanRT)/len(Resp_MeanRT))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Resp_MeanRT = -555
			
		try:
			Per_Int = float(keyed_mental/total_mental)
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Per_Int = -555
			
		try:
			Per_Unsure = float(keyed_unsure/(total_mental+total_random))
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Per_Unsure = -555
			
		try:
			Per_Random = float(keyed_random/total_random)
		except ZeroDivisionError:
			print ("WARNING ZeroDivisionError")
			Per_Random = -555
			
		Stats.write("Mean RT: " + str(Resp_MeanRT) +"\n")
		Stats.write("Percent Interaction: " + str(Per_Int)+"\n")
		Stats.write("Percent Random: " + str(Per_Random)+"\n")
		Stats.write("Percent Unsure: " + str(Per_Unsure)+"\n")
		Stats.write("Percent No Response: " + str(NLR)+"\n")
			
	
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