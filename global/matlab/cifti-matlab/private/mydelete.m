function mydelete(filename)
    %fix matlab's "error if doesn't exist" and braindead "send to recycling based on preference" misfeatures
    if exist(filename, 'file')
        recstatus = recycle();
        cleanupObj = onCleanup(@()(recycle(recstatus)));
        recycle('off');
        delete(filename);
    end
end
