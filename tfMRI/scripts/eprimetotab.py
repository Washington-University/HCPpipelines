import sys, os

def main():
	
		for arg in sys.argv[1:]:
		#catch directory - v1/v2/v3/v4
			directory = arg
			#attempt to open for reading
			dirList = os.listdir(directory)
			#iterate through file list
			for item in dirList:
				if item[-4:] == ".txt" and item[-8:] != "_TAB.txt":
					cmd = "/usr/lib/ruby/gems/1.8/gems/optimus-ep-0.9.1/bin/eprime2tabfile " + directory + item + " -o " + directory + item[:-4] + "_TAB.txt"
					os.system(cmd)
				
if __name__ == "__main__":
	main()
