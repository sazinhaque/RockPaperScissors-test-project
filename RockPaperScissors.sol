// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RockPaperScissor{
    using Counters for Counters.Counter;
    Counters.Counter private _gameId;
    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); //Using DAI stablecoin

    enum Moves {NONE, ROCK, PAPER, SCISSORS}
    Moves public move; 
    struct Game {
        uint256 endTime;     
        address participant1;
        address participant2;
        bool active;  
    }
    struct PlayerInfo{
        uint256 wager;
        Moves move;
    }
    mapping(uint256=>mapping(address=>PlayerInfo)) private idToPlayerInfo;
    mapping (address=>bool) enrolledPlayers;
    mapping (address=>bool) isPlaying;
    mapping (address=>uint256) private playerToWinnings;
    mapping (uint256=>Game) idToGame;

    event GameStart(address player1, address player2);
    event GameEnd(address indexed winner, uint256 wager, uint256 time);

    modifier checkPlayer(uint256 _id, Moves _move, uint256 _wager){
        require(idToGame[_id].active, "Game has ended");
        require(msg.sender == idToGame[_id].participant1 || msg.sender == idToGame[_id].participant2, "You are not a participant");
        require(idToPlayerInfo[_id][msg.sender].move == Moves.NONE, "You have already made your move");
        require(_move != Moves.NONE, "Invalid move");
        require(_wager>=0 && dai.balanceOf(msg.sender)>=_wager, "Invalid wager amount");
        _;
    }
    function enroll(uint256 _amount) external {
        require(!enrolledPlayers[msg.sender], "Already enrolled");
        require(_amount>=0);
        enrolledPlayers[msg.sender] = true;
        dai.transferFrom(msg.sender, address(this), _amount);
    }
    
    function startGame(address _against) external returns (uint256) {
        require(enrolledPlayers[msg.sender] && enrolledPlayers[_against], "Both players must be enrolled");
        require(!isPlaying[msg.sender] && !isPlaying[_against], "Participant/s already in a game");
        _gameId.increment();
        uint256 currentId = _gameId.current();
        idToGame[currentId] = Game({
            endTime: block.timestamp + 6 hours,
            participant1: msg.sender,
            participant2: _against,
            active: true
        });
        isPlaying[msg.sender] = true;
        isPlaying[_against] = true;
        emit GameStart(msg.sender, _against);
        return currentId;
    }
    function makeMove(uint256 _id, Moves _move, uint256 _wager) external checkPlayer(_id, _move, _wager) {
        address player1 = idToGame[_id].participant1;
        address currentPlayer = msg.sender;
        //Adjust winnings and wager for current player
        if(currentPlayer == player1) {
            idToPlayerInfo[_id][currentPlayer].wager += _wager;
            playerToWinnings[currentPlayer] -= _wager;
        }else {
            idToPlayerInfo[_id][currentPlayer].wager += _wager;
            playerToWinnings[currentPlayer] -= _wager;
        }
      
        idToPlayerInfo[_id][currentPlayer].move = _move;

    }
    function endGame(uint256 _id) external {
        require(msg.sender == idToGame[_id].participant1 || msg.sender == idToGame[_id].participant2);
        require(idToGame[_id].active && block.timestamp > idToGame[_id].endTime, "Game has not ended");
        idToGame[_id].active = false;
        address winner = _getWinner(_id);
        uint256 wager1 = idToPlayerInfo[_id][idToGame[_id].participant1].wager;
        uint256 wager2 = idToPlayerInfo[_id][idToGame[_id].participant2].wager;
        if(winner == address(0)){
            //Refund participants in case of draw or uncooperative player
            wager1>0 && dai.transferFrom(address(this), idToGame[_id].participant1, wager1);
            wager2>0 && dai.transferFrom(address(this), idToGame[_id].participant2, wager2);
            emit GameEnd(winner, 0, block.timestamp);
        }else {
            uint256 winnings = wager1 + wager2; 
            playerToWinnings[winner] += winnings; //Update total winnings for the winner 
            dai.transferFrom(address(this), winner, winnings);
            emit GameEnd(winner, winnings, block.timestamp);
        }
        
    }
    function _getWinner(uint256 _id) private view returns (address) {
        address _player1 = idToGame[_id].participant1;
        address _player2 = idToGame[_id].participant2;
        Moves move1 = idToPlayerInfo[_id][_player1].move;
        Moves move2 = idToPlayerInfo[_id][_player2].move;
        if(move1 == move2 || move1 == Moves.NONE || move2 == Moves.NONE) return address(0);
        else if(move1 == Moves.ROCK && move2 == Moves.SCISSORS) return _player1;
        else if(move1 == Moves.PAPER && move2 == Moves.ROCK) return _player1;
        else if(move1 == Moves.SCISSORS && move2 == Moves.PAPER) return _player1;
        else return _player2;
    }
}