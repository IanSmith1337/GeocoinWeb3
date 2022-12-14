// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "./GCW3Admin.sol";

// Used to join a raffle for a geo-coin NFT.
contract GCW3RaffleV2 is Ownable, PullPayment, GCW3Admin {
    mapping (address => User) private _users;
    uint256 private _cost = 0.01 ether;
    address[] public registeredUsers;
    address[] public awardedUsers;
    address[] private weighted;
    
    struct User {
        address ID;
        uint tickets;
    }

    error UnevenPayment(uint sent, uint tickets, uint ticketCost);
    error InvalidAddress(address addr);
    error duplicateWinner(address addr);

    constructor () {}

    // Ensures user exists for current sender.
    function checkIfUserExists() private view returns (bool){
        if (_users[msg.sender].ID != address(0))
            return true;
        else
            return false;
    }

    // Ensures user is registered for the raffle.
    function checkIfUserIsRegistered() private view returns (bool) {
        for (uint256 i = 0; i < registeredUsers.length; i++) {
            if(msg.sender == registeredUsers[i]) 
                return true;
        }
        return false;
    }

    // Creates user.
    function addUser() public {
        require(!checkIfUserExists(), "Error: Cannot add duplicate user to contract.");
        _users[msg.sender] = User(msg.sender, 0);
    }

    // Allow user to buy into raffle
    function buyTickets(uint t) public payable {
        require(checkIfUserExists(), "Error: User doesn't exist yet.");
        require((_users[msg.sender].tickets += t) > _users[msg.sender].tickets, "Error: Ticket overflow.");

        if (msg.value % _cost > 0 || msg.value / _cost != t)
            revert UnevenPayment({
                sent: msg.value,
                tickets: t,
                ticketCost: _cost
            });
        else
            if (checkIfUserIsRegistered()) {
                super._asyncTransfer(this.owner(), msg.value);
                _users[msg.sender].tickets = _users[msg.sender].tickets + t;
            } else {
                super._asyncTransfer(this.owner(), msg.value);
                registeredUsers.push(msg.sender);
                _users[msg.sender].tickets = t;
            }
    }

    // Calculator func for weighted array
    // Example:
    // registeredUsers = {0x1, 0x2, 0x3, 0x4}
    // user.tickets = {1, 2, 3, 4}
    // weighted = {0x1, 0x2, 0x2, 0x3, 0x3, 0x3, 0x4, 0x4, 0x4, 0x4}
    function calcWeightedArrayFromRaffle() public isAdmin {
        for (uint256 i = 0; i < registeredUsers.length; i++) {
            for (uint256 j = 0; j < _users[registeredUsers[i]].tickets; j++) {
                weighted.push(registeredUsers[i]);
            }
        }
    }

    // Gets registered users from the raffle.
    function getAllFromRaffle() public view isAdmin returns (address[] memory){
        return registeredUsers;
    }

    // Gets weighted users from the raffle.
    function getWeightedFromRaffle() public view isAdmin returns (address[] memory){
        return weighted;
    }

    // Gets all winners from the raffle.
    function getWinnersFromRaffle() public view isAdmin returns (address[] memory){
        return awardedUsers;
    }

    // Gets number of tickets the current user has purchased for the next raffle.
    function getTicketCount() public view isAdmin returns (uint){
        require(checkIfUserExists(), "Error: User doesn't exist yet.");
        if(!checkIfUserIsRegistered())
            return 0;
        else 
            return _users[msg.sender].tickets;
    }

    // Adds winner from the raffle to awardedUsers.
    function setWinnersFromRaffle(address user) public isAdmin {
        for (uint256 u = 0; u < awardedUsers.length; u++) {
            if(user == awardedUsers[u]) 
                revert duplicateWinner({
                    addr: user
                });
        }
        awardedUsers.push(user);
    }

    /// @dev Overridden in order to make it an onlyOwner function
    function withdrawPayments(address payable payee) public override onlyOwner virtual {
        super.withdrawPayments(payee);
    }

    // resets raffle
    function reset() public isAdmin {
        for (uint256 i = 0; i < registeredUsers.length; i++) {
            _users[registeredUsers[i]].tickets = 0;
        }
        delete registeredUsers;
        delete awardedUsers;
        delete weighted;
    }

    // Op address as admin
    function OpAddress(address a) public onlyOwner {
        super.Op(a);
    }

    // deop address as admin
    function DeOpAddress(address a) public onlyOwner {
        super.DeOp(a);
    }
}