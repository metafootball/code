network="qitTest"
if [ ${2} ]
then
    network="${2}"
fi
npx hardhat --network $network run scripts/${1}.js