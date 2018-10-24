# Working directory with cloned repository: /daocloud/builder/src

echo Hello，world

echo $DAO_COMMIT_BRANCH 
echo 代码源提交时的分支
echo $DAO_COMMIT_TAG  
echo 代码源提交的标签
echo $DAO_COMMIT_SHA  
echo 代码源提交后的哈希号

echo $DAO_COMMIT_TAG | cut -d - -f 2
