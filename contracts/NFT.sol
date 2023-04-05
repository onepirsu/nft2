/**
*ERC-1155: Multi Token Standard
*１つのコントラクトで、複数のユーザーがNFTを発行できる仕様
*
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFT is ERC1155 ,Ownable{

    /**----------------------------------------------
    * initial setting（変数の定義など）
    ------------------------------------------------*/   
    uint256 constant ownerRoyaltyRate = 300;//3%
    
    //NFTの構造体定義
    struct NFTStr{
        uint256 id;
        uint256 issued;//発行数
        uint256 cost;
        address creater;
    }

    mapping(uint256=>bool) exist;//「tokenId => 真偽値」NFTが存在しているかのマッピング
    mapping(address=>uint256) balances;//アドレス毎の残高
    mapping(address=>uint256[]) createTokenId;//クリエイターが発行したtokenID
    mapping(uint256=>string) baseMetadataURIPrefix;//tokenId毎のbaseMetadataURI

    NFTStr[] NFTData;//NFTを保存しておく変数

    //デプロイ時に発行するNFTの設定
    constructor() public ERC1155("") {

    }

    /**----------------------------------------------
    * eventの定義
    ------------------------------------------------*/   
    event Mint(uint256 _id, uint256 _quantity, uint256 _cost , string _baseMetadataURIPrefix);
    event BuyToken(uint256 _id, uint256 _quantity, uint256 _cost);
    event Burn(uint256 _id, uint256 _quantity);
    event Withdraw(uint256 _amount);
    event SetURI(string _uri);

    /**----------------------------------------------
    * 関数修飾子の定義
    ------------------------------------------------*/   
    //NFTの存在チェック
    modifier existCheck(uint256 _id){
        require(exist[_id] == true ,"The NFT does not exist.");
        _;
    }

    //NFTのクリエイターチェック
    modifier createrCheck(address _creater ,uint256 _id){
        uint256[] memory _ids = createTokenId[_creater];
        uint _length = _ids.length;
        bool _flg = false;
        for(uint256 _i;_i < _length;_i++){
            if(_ids[_i] == _id){
                _flg = true;
                break;
            }
        }
        require(_flg == true ,"The NFT does not yours.");
        _;
    }

    /**----------------------------------------------
    * コントラクト関数の定義
    ------------------------------------------------*/ 

    /* 一般用の関数 
    ------------------------------------------------*/ 
     //特定のクリエイターのNFTの情報を取得する
    function getNFTList(address _creater) external view returns(NFTStr [] memory){
        NFTStr [] memory _NFTData = NFTData;
        uint256 [] memory _ids = createTokenId[_creater];
        uint256 _id;
        uint256 _length = _ids.length;
        NFTStr[] memory _creatersNFTData = new NFTStr[](_length); 
        for(uint256 _i = 0;_i < _length;_i++){
            _id = _ids[_i];
            _creatersNFTData[_i] = _NFTData[_id];
        }
        return _creatersNFTData;
    }

    //OpenSeaなどが、NFTのメタデータを取得する関数
    function uri(uint256 _id) public view override returns (string memory) {
        string memory _baseMetadataURIPrefix = baseMetadataURIPrefix[_id];
        return string(abi.encodePacked(
            _baseMetadataURIPrefix,
            Strings.toString(_id),
            ''
        ));
    }

    //特定のクリエイターの、自分が所持しているNFT数を取得
    function getOwnNFTList(address _creater) external view returns(uint256 [] memory , uint256 [] memory){
        uint256 [] memory _ids = createTokenId[_creater];
        uint256 _length = _ids.length;
        uint256 _balance;
        uint256 _id;
        uint256[] memory _balances = new uint256[](_length); 

        for (uint256 _i = 0; _i < _length; _i++){
            _id = _ids[_i];
            _balance = balanceOf(msg.sender,_id);
            _balances[_i] = _balance;
        }

        return (_ids,_balances);

    }

    //NTFを購入
    function buyToken(address _creater,uint256 _id,uint256 _cost ,uint256 _quantity) external payable existCheck(_id){
        
        uint256 _balance = balanceOf(_creater,_id);
        require(_cost == msg.value ,unicode"支払金額が正しくありません。");//unicodeを指定する事で、日本語を設定出来る。
        require(_creater != msg.sender ,unicode"受け取りアドレスが不正です。");//unicodeを指定する事で、日本語を設定出来る。
        require(_quantity > 0,unicode"数量は必須入力です。");//unicodeを指定する事で、日本語を設定出来る。
        require(_balance >= _quantity ,unicode"残数以上の数量が入力されています。");//unicodeを指定する事で、日本語を設定出来る。

        //トークンを購入者へ送る
        _safeTransferFrom(_creater,msg.sender,_id,_quantity,"");

        //コントラクトのオーナーへのロイヤリティを計算
        uint256 _ownerRoyalty = (msg.value / 10000) * 300; 
        uint256 _createrAmount = msg.value - _ownerRoyalty; 

        address _owner = owner();

        //クリエイターとオーナーへ送金
        balances[_creater] += _createrAmount;
        balances[_owner] += _ownerRoyalty;
        emit BuyToken(_id, _quantity, _cost);

    }

    //指定のアドレスが所持している残高
    function getBalance() external view returns(uint256){
        return balances[msg.sender];
    }

    //所持している残高から引き出す
    function withdraw() external{
        require(balances[msg.sender] > 0,unicode"残高がありません。");
        uint256 _amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(_amount);//msg.sender アドレスに、任意の_amountを送金する
        //msg.sender.transfer(_amount);//この書き方でもよいかも。
        emit Withdraw(_amount);
    }


    //新たなNTFを発行
    function mint(uint256 _quantity,uint256 _cost,string memory _baseMetadataURIPrefix) external{
        require(_quantity != 0 ,"quantity required.");
        require(_cost != 0 ,"cost required.");
        uint256 _id = NFTData.length;
        _mint(msg.sender, _id, _quantity, "");
        NFTStr memory newNFT = NFTStr(_id,_quantity,_cost,msg.sender);
        NFTData.push(newNFT);
        exist[_id] = true;
        createTokenId[msg.sender].push(_id);
        baseMetadataURIPrefix[_id] = _baseMetadataURIPrefix;
        emit Mint(_id, _quantity, _cost, _baseMetadataURIPrefix);
    }

    //NTFを燃やす
    function burn(uint256 _id,uint256 _quantity) external{
        uint256 _balance = balanceOf(msg.sender,_id);
        require(_balance >= _quantity,unicode"数量が所持数を超えています。");

        //指定のアドレスが所有している指定のIDのNTFを指定の数量燃やす関数
        _burn(msg.sender, _id, _quantity);
        emit Burn(_id, _quantity);
    }


    /* NFTの発行者（クリエイター）専用の関数 
    ------------------------------------------------*/ 
    //MetaDataのURIを変更
    function setURI(uint256 _id,string memory _uri) external createrCheck(msg.sender ,_id){
        require(keccak256(abi.encodePacked(_uri)) != keccak256(abi.encodePacked("")),unicode"URIが入力されていません。");//unicodeを指定する事で、日本語を設定出来る。
        baseMetadataURIPrefix[_id] = _uri;
        emit SetURI(_uri);
    }

    //NFTの発行者がいくつ所有しているか？＝NFTの残数がいくつか？
    function balanceOfCreater(uint256 _id) external view existCheck(_id) createrCheck(msg.sender ,_id) returns(uint256){
        uint256 _balance = balanceOf(msg.sender,_id);
        return _balance;
    }


}