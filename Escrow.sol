pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";



contract Escrow is Context,Ownable{
    
    using SafeERC20 for IERC20;
    using Address for address;
    using Counters for Counters.Counter;
    Counters.Counter public escrowId;
     
     
    /*struct for storing escrow details
      haveTokenAddress= address of a contract whose token user wants to deposit
      haveTokenAmount=deposit amount
      wantTokenContract=address of a contract whose token user wants against deposit
      wantTokenAmount=amount of tokens user wants against deposit
    */
    struct EscrowDetails {
        address escrowOwner;
        address haveTokenAddress;
        uint haveTokenAmount;
        address wantTokenAddress;
        uint wantTokenAmount;
        uint escrowId;
        bool escrowPurchased;
        bool escrowCompleted;
    }
    
    //mapping to store all escrow's, key=escrow id
    mapping (uint=>EscrowDetails) public Escrow;
    
    event EscrowCreated(address e_escrowOwner, address e_haveTokenAddress, uint e_haveTokenAmount, address e_wantTokenAddress, uint e_wantTokenAmount,  uint e_escrowId);
    event EscrowPurchased(uint e_escrowId, address e_buyer);
    event EscrowCompleted(uint e_escrowId);
    event EscrowDeleted(uint e_escrowId);
    
    receive() external payable{
        revert();
    }
    
    function createEscrow(address _haveTokenAddress, uint _haveTokenAmount, address _wantTokenAddress, uint _wantTokenAmount) public{
        
        require(_haveTokenAddress.isContract() && _wantTokenAddress.isContract(), "Invalid contract address");
        
        //creating contract instance
        IERC20 haveTokenContract = IERC20(_haveTokenAddress);
        
        //getting token amount this contract is allowed to spend
        uint haveAmountAllowed = haveTokenContract.allowance(_msgSender(), address(this));
        
        //checking token allowed to spend should be greater than deposit amount
        require( haveAmountAllowed >= _haveTokenAmount, "Insufficient token allowance");
        
        haveTokenContract.safeTransferFrom(_msgSender(),address(this),_haveTokenAmount);
        
        //first escrow will have id of 1
        escrowId.increment(); 
        
        Escrow[escrowId.current()] = EscrowDetails(_msgSender(),_haveTokenAddress,_haveTokenAmount,_wantTokenAddress,_wantTokenAmount,escrowId.current(),false,false);
        emit EscrowCreated(_msgSender(),_haveTokenAddress,_haveTokenAmount,_wantTokenAddress,_wantTokenAmount,escrowId.current());
        
    }
    
    function purchaseEscrow(uint _escrowId) public{
        require(_escrowId>0&&escrowId.current()>=_escrowId,"No Escrow exist with such id");
        require(Escrow[_escrowId].escrowOwner!=_msgSender(),"You can't purchase your own Escrow");
        require(Escrow[_escrowId].escrowPurchased==false,"Escrow is already purchased");
        
        IERC20 wantTokenContract = IERC20(Escrow[_escrowId].wantTokenAddress);
        uint tokenAmountAllowed = wantTokenContract.allowance(_msgSender(), address(this));
        require( tokenAmountAllowed >= Escrow[_escrowId].wantTokenAmount, "Insufficient token allowance");
        Escrow[_escrowId].escrowPurchased=true;
        
        //transferring tokens from Escrow buyer to the smart contract
        wantTokenContract.safeTransferFrom(_msgSender(),address(this),Escrow[_escrowId].wantTokenAmount);
        
        //transferring tokens from the smart contract to the Escrow buyer
        IERC20 haveTokenContract = IERC20(Escrow[_escrowId].haveTokenAddress);
        haveTokenContract.safeTransfer(_msgSender(),Escrow[_escrowId].haveTokenAmount);
        
        emit EscrowPurchased(_escrowId,_msgSender());
    }
    
    function completeEscrow(uint _escrowId) public {
        require(_escrowId>0&&escrowId.current()>=_escrowId,"No Escrow exist with such id");
        require(Escrow[_escrowId].escrowOwner==_msgSender(),"Permission to complete Escrow denied!");
        require(Escrow[_escrowId].escrowPurchased==true,"Escrow is not Purchased yet");
        require(Escrow[_escrowId].escrowCompleted==false,"Escrow is already completed");
        
        Escrow[_escrowId].escrowCompleted=true;
        
        //transferring tokens (escrow owner wanted against his deposit) to the Escrow owner since escrow has been purchased
        IERC20 wantTokenContract = IERC20(Escrow[_escrowId].wantTokenAddress);
        wantTokenContract.safeTransfer(_msgSender(),Escrow[_escrowId].wantTokenAmount);
        
        emit EscrowCompleted(_escrowId);
    }
    
    function deleteEscrow(uint _escrowId) public{
        require(_escrowId>0&&escrowId.current()>=_escrowId,"No Escrow exist with such id");
        require(Escrow[_escrowId].escrowOwner==_msgSender(),"Permission to delete Escrow denied!");
        require(Escrow[_escrowId].escrowPurchased==false,"Purchased escrow can not be deleted");
        
        IERC20 haveTokenContract = IERC20(Escrow[_escrowId].haveTokenAddress);
        uint transferDeposit = Escrow[_escrowId].haveTokenAmount;
        
        //deleting escrow
        delete Escrow[_escrowId];
        
        //transferring Escrow owner's deposit back
        haveTokenContract.safeTransfer(_msgSender(),transferDeposit);
        
        emit EscrowDeleted(_escrowId);
    }
    
    function checkTokenBalance(address _tokenBalanceAddress) view public returns(uint){
        IERC20 tokenBalanceContract = IERC20(_tokenBalanceAddress);
        uint tokenBalance = tokenBalanceContract.balanceOf(address(this));
        return tokenBalance;
    }
}