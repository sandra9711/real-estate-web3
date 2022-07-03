const main = async () => {
    const [owner, randomPerson] = await hre.ethers.getSigners()
    const auctionContractFactory = await hre.ethers.getContractFactory('Auction')
    const auctionContract = await auctionContractFactory.deploy(
        '0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097',
        2,
        2,
        30,
        'ipfs'
    )
    await auctionContract.deployed()
    console.log('Contract deployed to:', auctionContract.address)
    console.log('Contract deployed by:', owner.address)
    let s = await auctionContract.placeBid()
    console.log(s)
}
//Contract deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
const runMain = async () => {
    try {
        await main()
        process.exit(0) // exit Node process without error
    } catch (error) {
        console.log(error)
        process.exit(1) // exit Node process while indicating 'Uncaught Fatal Exception' error
    }
    // Read more about Node exit ('process.exit(num)') status codes here: https://stackoverflow.com/a/47163396/7974948
}

runMain()
