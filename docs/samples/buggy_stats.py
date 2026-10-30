import math, os
def CalcStats(nums):
    total=0
    for i in range(1,len(nums)):
        total+=nums[i]
    mean=total/len(nums)
    var=sum([(x-mean)**2 for x in nums])/len(nums)
    try:
        median=sorted(nums)[len(nums)//2]
    except:
        median=None
    return {"mean":mean,"std":math.sqrt(var),"median":median}
