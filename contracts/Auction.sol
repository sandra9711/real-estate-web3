// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Auction {
    // static
    address public owner;
    uint256 public bidIncrement;
    uint256 public startBlock;
    uint256 public endBlock;
    string public ipfsHash;

    // state
    bool public canceled;
    uint256 public highestBindingBid;
    address public highestBidder;
    mapping(address => uint256) public fundsByBidder;
    bool ownerHasWithdrawn;

    event LogBid(
        address bidder,
        uint256 bid,
        address highestBidder,
        uint256 highestBid,
        uint256 highestBindingBid
    );
    event LogWithdrawal(
        address withdrawer,
        address withdrawalAccount,
        uint256 amount
    );
    event LogCanceled();

    constructor(
        address _owner,
        uint256 _bidIncrement,
        uint256 _startBlock,
        uint256 _endBlock,
        string memory _ipfsHash
    ) {
        owner = _owner;
        bidIncrement = _bidIncrement;
        startBlock = _startBlock;
        endBlock = _endBlock;
        ipfsHash = _ipfsHash;
    }

    function getHighestBid() public view returns (uint256) {
        return fundsByBidder[highestBidder];
    }

    function placeBid()
        public
        payable
        onlyNotCanceled
        onlyNotOwner
        returns (bool success)
    {
        // reject payments of 0 ETH
        // if (msg.value == 0) revert("Not enough Ether provided.");
        //console.log("payment rejected (0 eth)");
        // calculate the user's total bid based on the current amount they've sent to the contract
        // plus whatever has been sent with this transaction
        uint256 newBid = fundsByBidder[msg.sender] + msg.value;

        // if the user isn't even willing to overbid the highest binding bid, there's nothing for us
        // to do except revert the transaction.

        //if (newBid <= highestBindingBid) revert("Not enough Ether provided.");

        // grab the previous highest bid (before updating fundsByBidder, in case msg.sender is the
        // highestBidder and is just increasing their maximum bid).
        uint256 highestBid = fundsByBidder[highestBidder];

        fundsByBidder[msg.sender] = newBid;

        if (newBid <= highestBid) {
            // if the user has overbid the highestBindingBid but not the highestBid, we simply
            // increase the highestBindingBid and leave highestBidder alone.

            // that this case is impossible if msg.sender == highestBidder because you can never
            // bid less ETH than you've already bid.

            highestBindingBid = min(newBid + bidIncrement, highestBid);
        } else {
            // if msg.sender is already the highest bidder, they must simply be wanting to raise
            // their maximum bid, in which case we shouldn't increase the highestBindingBid.

            // if the user is NOT highestBidder, and has overbid highestBid completely, we set them
            // as the new highestBidder and recalculate highestBindingBid.

            if (msg.sender != highestBidder) {
                highestBidder = msg.sender;
                highestBindingBid = min(newBid, highestBid + bidIncrement);
            }
            highestBid = newBid;
            //console.log("bid success");
        }

        emit LogBid(
            msg.sender,
            newBid,
            highestBidder,
            highestBid,
            highestBindingBid
        );
        return true;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        if (a < b) return a;
        return b;
    }

    function cancelAuction()
        public
        onlyOwner
        onlyNotCanceled
        returns (bool success)
    {
        canceled = true;
        emit LogCanceled();
        return true;
    }

    function withdraw() public onlyEndedOrCanceled returns (bool success) {
        address withdrawalAccount;
        uint256 withdrawalAmount;

        if (canceled) {
            // if the auction was canceled, everyone should simply be allowed to withdraw their funds
            withdrawalAccount = msg.sender;
            withdrawalAmount = fundsByBidder[withdrawalAccount];
        } else {
            // the auction finished without being canceled

            if (msg.sender == owner) {
                // the auction's owner should be allowed to withdraw the highestBindingBid
                withdrawalAccount = highestBidder;
                withdrawalAmount = highestBindingBid;
                ownerHasWithdrawn = true;
            } else if (msg.sender == highestBidder) {
                // the highest bidder should only be allowed to withdraw the difference between their
                // highest bid and the highestBindingBid
                withdrawalAccount = highestBidder;
                if (ownerHasWithdrawn) {
                    withdrawalAmount = fundsByBidder[highestBidder];
                } else {
                    withdrawalAmount =
                        fundsByBidder[highestBidder] -
                        highestBindingBid;
                }
            } else {
                // anyone who participated but did not win the auction should be allowed to withdraw
                // the full amount of their funds
                withdrawalAccount = msg.sender;
                withdrawalAmount = fundsByBidder[withdrawalAccount];
            }
        }

        if (withdrawalAmount == 0) revert();

        fundsByBidder[withdrawalAccount] -= withdrawalAmount;

        // send the funds
        if (!payable(msg.sender).send(withdrawalAmount)) revert();

        emit LogWithdrawal(msg.sender, withdrawalAccount, withdrawalAmount);

        return true;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert();
        _;
    }

    modifier onlyNotOwner() {
        if (msg.sender == owner) revert();
        _;
    }

    modifier onlyNotCanceled() {
        if (canceled) revert();
        _;
    }

    modifier onlyEndedOrCanceled() {
        if (block.number < endBlock && !canceled) revert();
        _;
    }
}
