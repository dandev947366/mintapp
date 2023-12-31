// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./Main.sol";
import "./Shared.sol";


contract Session is Shared {
   
    Main private mainContract;
    using Math for uint;

    using Counters for Counters.Counter;
    Counters.Counter private _totalItem;
    Counters.Counter private _NoOfParticipant;
    Counters.Counter private _NoOfSession;
    mapping(uint256 => mapping(address => uint256)) bids;

    constructor(address _mainContract) {
        mainContract = Main(_mainContract);
        admin = msg.sender;
    }
    
    function joinSession(
        uint256 _sessionId
    ) public returns (Iparticipant memory) {
        require(_sessionId > 0, "Session ID cannot be empty");
        require(msg.sender != admin, "Owner not allow to join session");
        SessionStruct memory session = mainContract.getSession(_sessionId);
        require(
            session.NoOfParticipant < 10,
            "Maximum amount of participants reached."
        );
        require(!session.completed, "Session completed.");
        require(!session.deleted, "Session deleted.");

        Iparticipant memory joiner;
        joiner.participantWallet = msg.sender;
        joiner.isParticipate = true;
        joiner.NoOfSession += 1;
        participantOf[_sessionId] = joiner;
        participantList[_sessionId].push(joiner);

        emit Action("Join session successfully");
        return joiner;
    }

    function getParticipants(
        uint256 _sessionId
    ) public view returns (Iparticipant[] memory) {
        require(_sessionId > 0, "Session ID cannot be empty");
        return participantList[_sessionId];
    }

    function calcFinalPrice(uint256 _sessionId) public view onlyOwner returns (uint256){
        require(_sessionId > 0, "Session ID cannot be empty");
        Iparticipant[] memory pList = participantList[_sessionId];
    
        uint256 bid;
        uint256 sum;
        uint256 finalPrice;
        address pAddress;
        for(uint256 i =0; i< pList.length;i++){
            pAddress = pList[i].participantWallet;
            bid = getBidAverage(_sessionId, pAddress);
            sum += bid;
        }
        finalPrice = sum / pList.length;
        return finalPrice;
    }

    function getBidAverage(uint _sessionId, address _participant) public view returns (uint256){
        require(_sessionId > 0, "Session ID cannot be empty.");
        require(_participant != address(0), "Address cannot be empty");
        uint256[] memory bList = bidList[_sessionId][_participant];
        uint256 sum;
        uint256 average;
        for (uint256 i =0; i <bList.length;i++){
            sum += bList[i];
        }
        average = sum/bList.length;
        return average;
    }

    function setWinner(uint _sessionId, address _participant) public onlyOwner {
        require(_sessionId > 0, "Session ID cannot be empty.");
        require(_participant != address(0), "Address cannot be empty");
        sessionOf[_sessionId].winner = _participant;
        emit Action("Set winner successfully");
    }

    function getWinner(uint _sessionId) public view returns(address){
        require(_sessionId > 0, "Session ID cannot be empty.");
        return sessionOf[_sessionId].winner;
    }

    function startPricing(
        uint256 _sessionId,
        uint256 _itemId,
        uint256 _amount
    ) public {
        require(_sessionId > 0, "Session ID cannot be empty.");
        require(_itemId > 0, "Item ID cannot be empty.");
        require(_amount > 0, "Amount cannot be empty");
        require(
            participantOf[_sessionId].participantWallet == msg.sender,
            "Invalid participant."
        );
        Item memory item;
        item.id = _itemId;
        item.status = Status.RUNNING;
        bids[_sessionId][msg.sender] = _amount;
        participantOf[_sessionId].NoOfBids++;
        participantOf[_sessionId].NoOfBids++;
        participantOf[_sessionId].isParticipate = true;
        participantOf[_sessionId].participantWallet = msg.sender;
        int sId = castUintToInt(_sessionId);
        int amount = castUintToInt(_amount);
        bidListCal[sId][msg.sender].push(amount);
        bidList[_sessionId][msg.sender].push(_amount);
        emit Action("Bid item successfully");
    }
    
    function getBidList(
        uint256 _sessionId,
        address _participant
    ) public view returns (uint256[] memory) {
        require(_sessionId > 0, "Session ID cannot be empty.");
        require(_participant != address(0), "Address cannot be empty");
        return bidList[_sessionId][_participant];
    }

    function getTotalBids(
        uint256 _sessionId,
        address _participant
    ) public view returns (uint256) {
        require(_sessionId > 0, "Session ID cannot be empty.");
        require(_participant != address(0), "Address cannot be empty");
        uint256[] memory totalBids = getBidList(_sessionId, _participant);
        return totalBids.length;
    }

    function calcDeviation(
        address _participant,
        uint256 _sessionId
    ) public onlyOwner view returns (int256) {
        //Source: https://vietnambiz.vn/do-lech-chuan-standard-deviation-la-gi-cong-thuc-tinh-do-lech-chuan-2019110216112891.htm
        require(_sessionId > 0, "Session ID cannot be empty.");
        require(_participant != address(0), "Address cannot be empty");
        int sId = castUintToInt(_sessionId);
        uint256 total = getTotalBids(_sessionId, _participant);
        int256 totalNew = castUintToInt(total);
        int256[] memory totalBids = bidListCal[sId][msg.sender];
        int256 sum;
        int256 average;
        int256 variantSum;
        int256 v;
        int256 deviation;

        // Calculate the sum of bids
        for (uint256 i = 0; i < totalBids.length; i++) {
            sum += totalBids[i];
        }

        // Calculate the average
        average = sum / totalNew;

        // Calculate the sum of squared differences
        for (uint256 i = 0; i < totalBids.length; i++) {
            v = totalBids[i] - average;
            v = v * v;
            variantSum += v;
        }

        // Calculate variance
        variantSum = variantSum / totalNew;

        // Calculate standard deviation (square root of variance)
        deviation = sqrt(variantSum);

        return deviation;
    }

    function castUintToInt(uint256 value) internal pure returns (int256) {
        require(value <= uint256(int256(-1)), "Value exceeds int256 range");
        return int256(value);
    }

    function castIntToUint(int256 value) internal pure returns (uint256) {
        require(value >= 0, "Value is negative"); // Check if the value is non-negative
        return uint256(value);
    }

    function sqrt(int256 x) internal pure returns (int256 y) {
        int256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
