"""
Find the neighbors of each vertex. 
"""

def neighbor_info(a,b,c,x,y,z,subjects_dir,subject,hemi,surface,mesh):
    
    import numpy as np
    import os
    
    neighbors_unsorted = [set() for _ in range(len(x))]
    triangles_unsorted = [set() for _ in range(len(x))]
    
    def add_neighbor(neighbors, whichtri, verts, first, second):
        triangles_unsorted[verts[first]].add(whichtri)
        neighbors[verts[first]].add(verts[second])
        neighbors[verts[second]].add(verts[first])
    
    for triind in range(len(a)):
        triverts = [int(a[triind]), int(b[triind]), int(c[triind])]
        add_neighbor(neighbors_unsorted, triind, triverts, 0, 1)
        add_neighbor(neighbors_unsorted, triind, triverts, 1, 2)
        add_neighbor(neighbors_unsorted, triind, triverts, 2, 0)
        
    #numneigh says how many neighbors exist per vertex
    #numtris how many triangles use a vertex (should be the same)
    #neighbors_unsorted has the vertices that are neighors, in an arbitrary order
    #triangles_unsorted has the triangle indices that contain the vertex, in an arbitrary order
    
    maxneigh = -1
    for vert in range(len(x)):
        maxneigh = max(maxneigh, len(neighbors_unsorted[vert]))
    
    neighbors_sorted = np.zeros((len(x), maxneigh + 2))
    numneigh = [0] * len(x)
    firstbad = True
    for center in range(len(x)):
        lastneigh = -1
        firsttri = next(iter(triangles_unsorted[center]))
        myverts = [int(a[firsttri]), int(b[firsttri]), int(c[firsttri])]
        for i in range(3):
            if myverts[i] == center:
                break
        firstneigh = myverts[(i + 1) % 3]
        curneigh = myverts[(i + 1) % 3]
        nextneigh = myverts[(i + 2) % 3]
        neighbors_sorted[center, numneigh[center]] = firstneigh
        numneigh[center] += 1
        used = {curneigh}
        while True:
            lastneigh = curneigh
            curneigh = nextneigh
            used.add(curneigh)
            neighbors_sorted[center, numneigh[center]] = curneigh
            numneigh[center] += 1
            
            #this should only give two triangles
            possibletris = triangles_unsorted[center].intersection(triangles_unsorted[curneigh])
            if len(possibletris) != 2:
                raise RuntimeError("not good")
            possibleverts = set()
            for sometri in possibletris:
                possibleverts |= {int(a[sometri]), int(b[sometri]), int(c[sometri])}
            #should have 4 verts: center, prev, cur, and next, so...
            if len(possibleverts) != 4:
                raise RuntimeError("also not good")
            possibleverts.remove(curneigh)
            possibleverts.remove(center)
            possibleverts.remove(lastneigh)
            if len(possibleverts) != 1:
                raise RuntimeError("very not good")
            nextneigh = next(iter(possibleverts))
            
            if nextneigh == -1:
                raise RuntimeError("uhoh")
            if nextneigh in used:
                if nextneigh != firstneigh:
                    print('warning: vertex {} has unusual topology'.format(center))
                    if firstbad:
                        firstbad = False
                        print(neighbors_unsorted[center])
                        print(triangles_unsorted[center])
                        for tri in triangles_unsorted[center]:
                            print([int(a[tri]), int(b[tri]), int(c[tri])])
                        print(neighbors_sorted[center])
                break
        #add the extra wraparound vertices
        for i in range(2):
            neighbors_sorted[center, numneigh[center] + i] = neighbors_sorted[center, i]
            
        # add a new first column with vertex indices
    
    indices = np.arange(len(x))
    neighbors_sorted = np.transpose(np.vstack((indices, np.transpose(neighbors_sorted))))
    
    # put more columns of zero at the end
    zeros = np.zeros(len(x))
    neighbors_sorted = np.transpose(np.vstack((np.transpose(neighbors_sorted), zeros)))
    neighbors_sorted = np.transpose(np.vstack((np.transpose(neighbors_sorted), zeros)))
    neighbors_sorted = np.transpose(np.vstack((np.transpose(neighbors_sorted), zeros)))
    neighbors_sorted = np.transpose(np.vstack((np.transpose(neighbors_sorted), zeros)))
    neighbors_sorted = np.transpose(np.vstack((np.transpose(neighbors_sorted), zeros)))
    
    ######################## Save to asc file #############################
    connectivity = '{sub}.{h}.{s}.neighbor.asc'.format(sub=subject,h=hemi,s=surface) # first two neighbors are recurring for closing the triangle loop
    save_file = os.path.join(subjects_dir, subject,'MNINonLinear','Native', 'CorrThick', connectivity)
    np.savetxt(save_file, neighbors_sorted, fmt='%-4d', delimiter=' '' ')
    
    return neighbors_sorted

