//Level Controller
const int EVT_UPDATE = 1;
const int EVT_KEYDOWN = 2;
const int EVT_MOUSECLICK = 3;
const int EVT_MOUSEMOVE = 4;
const int EVT_SOUNDFINISH = 5;

	
//Bullet Physics Mask
const int BULLET_COLLISION_LAYER = 1;
const int PLAYER_COLLISION_LAYER = 2;
const int DRONE_COLLISION_LAYER = 3;
const int FLOOR_COLLISION_LAYER = 5;
const int SCORE_ADDITION_RATE = 1;

enum LevelState
{
	LS_INGAME = 101,
	LS_OUTGAME,
	LS_PAUSED
}


//===NOTE
//Add support for Game Controller

abstract class LevelManager : ScriptObject
{
	protected bool isInitialised = false;
	protected bool isActivated = false;
	protected SoundSource@ backgroundMusicSource_;
	
		
	bool initialised
	{
		get const
		{
			return isInitialised;
		}
	}
	
	
	bool activated
	{
		get const
		{
			return isActivated;
		}
	}
	
	
	void Initialise()
	{
		if(isInitialised)
		{
			return;
		}
		CreateAudioSystem();
		SetupLevel();
		isInitialised = true;
	}
	
	void Activate()
	{		
		if(!isInitialised)
		{
			return;
		}
		
		isActivated = true;
	}

	
	void Deactivate()
	{
		if(!isInitialised)
		{
			return;
		}
		
		isActivated = false;
	}
	
		
	void InitialiseAndActivate()
	{
		Initialise();
		Activate();
	}
	
	
	void SetupLevel(){}
	void HandleLevelEvent(VariantMap& eventData){}
	
	protected void SetViewportCamera(Camera@ viewCamera)
	{
		renderer.viewports[0] = Viewport(scene, viewCamera);
	}
	
	
	private void CreateAudioSystem()
	{
		audio.masterGain[SOUND_MASTER] = 0.75;
		audio.masterGain[SOUND_MUSIC] = 0.13;
		audio.masterGain[SOUND_EFFECT] = 0.5;
		
		Node@ backgroundMusicNode = scene.CreateChild();
		backgroundMusicSource_ = backgroundMusicNode.CreateComponent("SoundSource");
		backgroundMusicSource_.soundType = SOUND_MUSIC;
		
	}
	
	
	protected void SetSoundListener(Node@ listenerNode)
	{
		if(listenerNode.GetComponent("SoundListener") is null)
		{
			return;
		}
		audio.listener = listenerNode.GetComponent("SoundListener");
	}
	
}


//=========================== LEVEL ONE MANAGER ==========================================


class LevelOneManager : LevelManager
{

	uint MAX_DRONE_COUNT = 15;

	float EASY_PHASE = 0;
	float MODERATE_PHASE = 60;
	float CRITICAL_PHASE = 120;
	float EASY_PHASE_RATE = 5;
	float MODERATE_PHASE_RATE = 3;
	float CRITICAL_PHASE_RATE = 1;
	float SCENE_TO_UI_SCALE = 1.6f;
	float SPRITE_UPDATE_TIME = 0.04f;

	String NORMAL_DRONE_SPRITE = "Resources/Textures/drone_sprite.png";
	String ALTERNATE_DRONE_SPRITE = "Resources/Textures/alt_drone_sprite.png";
	
	int playerScore_ = 0;

	float spriteUpdateCounter_ = 0.0f;
	float droneSpawnCounter_ = 0.0f;
	float gamePhaseCounter_ = 0.0f;
	
	
	bool playerDestroyed_ = false;

	int joydirection_ = -1;  // which way the game controller wants to go

	String optionsMessage_ = "<SPACE> To Replay | <ESC> To Quit";

	LevelState levelState_ = LS_OUTGAME;

	Node@ cameraNode_;
	Node@ playerNode_;

	Viewport@ viewport_;


	ValueAnimation@ damageAnimation_;
	ValueAnimation@ textAnimation_;

	Sprite@ radarScreenBase_;
	Sprite@ healthFillSprite_;
	Sprite@ targetSprite_;

	Text@ enemyCounterText_;
	Text@ playerScoreText_;
	Text@ statusText_;
	Text@ playerScoreMessageText_;
	Text@ optionsInfoText_;
	
	void Activate()
	{
		LevelManager::Activate();
	}
	
	void Deactivate()
	{
		LevelManager::Deactivate();
		scene.updateEnabled = false;
	}
	
	void SetupLevel()
	{
		LoadDisplayInterface();
		LoadBackgroundResources();
		LoadAttributeAnimations();
		SetupScene();
		CreateCameraAndLight();
		SubscribeToEvents();
		StartGame();
	}
	
	private void SetupScene()
	{
		scene.updateEnabled = false;
	}

	
	void LoadDisplayInterface()
	{
		UIElement@ displayRoot = ui.root.CreateChild("UIElement");
		
		displayRoot.LoadXML(cache.GetFile("Resources/UI/ScreenDisplay.xml"));
		
		//Load the various UI Elements
		healthFillSprite_ = displayRoot.GetChild("HealthFill", true);
		radarScreenBase_ = displayRoot.GetChild("RadarScreenBase");
		
		targetSprite_ = displayRoot.GetChild("Target");
		
		enemyCounterText_ = displayRoot.GetChild("EnemyCounter");
		playerScoreText_ = displayRoot.GetChild("PlayerScore");
		
		
		statusText_ = displayRoot.GetChild("StatusText");
		playerScoreMessageText_ = displayRoot.GetChild("ScoreMessage");
		optionsInfoText_ = displayRoot.GetChild("OptionInfo");
	}
	
	
	void LoadBackgroundResources()
	{
		cache.BackgroundLoadResource("Model","Resources/Models/drone_body.mdl");
		cache.BackgroundLoadResource("Model","Resources/Models/drone_arm.mdl");
		cache.BackgroundLoadResource("Animation","Resources/Models/open_arm.ani");
		cache.BackgroundLoadResource("Animation","Resources/Models/close_arm.ani");
		
		cache.BackgroundLoadResource("Texture2D", "Resources/Textures/explosion.png");
		
		cache.BackgroundLoadResource("ParticleEffect", "Resources/Particles/bullet_particle.xml");
		cache.BackgroundLoadResource("ParticleEffect", "Resources/Particles/explosion.xml");
		
		cache.BackgroundLoadResource("Material","Resources/Materials/drone_arm.xml");
		cache.BackgroundLoadResource("Material","Resources/Materials/drone_body.xml");
		cache.BackgroundLoadResource("Material", "Resources/Materials/bullet_particle.xml");
		cache.BackgroundLoadResource("Material", "Resources/Materials/explosion.xml");
		
		cache.BackgroundLoadResource("Texture2D", "Resources/Textures/drone_sprite.png");
		cache.BackgroundLoadResource("Texture2D", "Resources/Textures/health_bar_green.png");
		cache.BackgroundLoadResource("Texture2D", "Resources/Textures/health_bar_red.png");
		cache.BackgroundLoadResource("Texture2D", "Resources/Textures/health_bar_yellow.png");
		
		cache.BackgroundLoadResource("Sound", "Resources/Sounds/boom1.wav");
		
		
	}


	void LoadAttributeAnimations()
	{
		textAnimation_ = cache.GetResource("ValueAnimation", "Resources/AttributeAnimations/GameStartCounterAnimation.xml");
		damageAnimation_ = cache.GetResource("ValueAnimation", "Resources/AttributeAnimations/DamageWarningAnimation.xml");
	}
	
	
	void CreateCameraAndLight()
	{
		cameraNode_ = scene.CreateChild();
		cameraNode_.CreateComponent("Camera");
		cameraNode_.Translate(Vector3(0,1.7,0));
		
		Node@ lightNode = cameraNode_.CreateChild("DirectionalLight");
		lightNode.direction = Vector3(0.6f, -1.0f, 0.8f);
		Light@ light = lightNode.CreateComponent("Light");
		light.lightType = LIGHT_DIRECTIONAL;	
		
		cameraNode_.CreateComponent("SoundListener");
		
		SetViewportCamera(cameraNode_.GetComponent("Camera"));
		
		Viewport@ viewPort = renderer.viewports[0];
		
		RenderPath@ rPath = viewPort.renderPath;
		rPath.Append(cache.GetResource("XMLFile", "PostProcess/Blur.xml"));
		rPath.SetEnabled("Blur",true);
	}
	
	
	void CreatePlayer()
	{
		
		playerNode_ = scene.CreateChild("PlayerNode");
		Node@ cameraNode = playerNode_.CreateChild("CameraNode");
		cameraNode.CreateComponent("Camera");
		cameraNode.Translate(Vector3(0,1.7,0));
		
		ScriptFile@ sFile = cache.GetResource("ScriptFile","Resources/Scripts/GameObjects.as");
		playerNode_.CreateScriptObject(sFile,"PlayerObject");
		
		cameraNode.CreateComponent("SoundListener");
		SetSoundListener(cameraNode);
		
		SetViewportCamera(cameraNode.GetComponent("Camera") );
		
		playerDestroyed_ = false;

	}
	
	

	void SubscribeToEvents()
	{
		SubscribeToEvent("PlayerHit","HandlePlayerHit");
		SubscribeToEvent("DroneDestroyed", "HandleDroneDestroyed");
		SubscribeToEvent("CountFinished", "HandleCountFinished");
		SubscribeToEvent("SoundGenerated", "HandleSoundGenerated");
		SubscribeToEvent("PlayerDestroyed", "HandlePlayerDestroyed");
		SubscribeToEvent("PlayerHealthUpdate", "HandlePlayerHealthUpdate");
		SubscribeToEvent(scene.physicsWorld, "PhysicsPreStep", "HandleFixedUpdate");
		
	}

	
	
	void StartCounterToGame()
	{
		statusText_.SetAttributeAnimation("Text", textAnimation_,WM_ONCE);
	}
	
	void StartGame()
	{
		playerScoreMessageText_.text = "";
		optionsInfoText_.text = "";
		gamePhaseCounter_ = 0.0f;
		droneSpawnCounter_ = 0.0f;
		playerScore_ = 0;
		
		SetSoundListener(cameraNode_);

		PlayBackgroundMusic("Resources/Sounds/cyber_dance.ogg");
		StartCounterToGame();
	}

	
	void InitiateGameOver()
	{
		scene.updateEnabled = false;
		levelState_ = LS_OUTGAME;
		
		CleanupScene();
		
		renderer.viewports[0].renderPath.SetEnabled("Blur",true);
		
		PlayBackgroundMusic("Resources/Sounds/defeated.ogg");
		
		targetSprite_.visible = false;
		statusText_.text = "YOU FAILED";
		playerScoreMessageText_.text = "Score : " + String(playerScore_);
		optionsInfoText_.text = optionsMessage_ ;

	}
	
	
	void CleanupScene()
	{
		//Remove All Nodes with script object : Drones, Bullets and even the player
		Array<Node@> scriptedNodes = scene.GetChildrenWithScript(true);
		for(uint i=0; i < scriptedNodes.length ; i++)
		{
			Node@ scriptNode = scriptedNodes[i];
			Sprite@ nodeSprite = scriptNode.vars["Sprite"].GetPtr();
			
			if(nodeSprite !is null)
			{
				nodeSprite.Remove();
			}
			
			scriptNode.Remove();
		}
		
		
		//Hide the enemy counter and player score texts
		enemyCounterText_.text = "";
		playerScoreText_.text = "";

	}
	
	

	void HandlePlayerHit()
	{
		//Show Warning
		radarScreenBase_.SetAttributeAnimation("Color", damageAnimation_, WM_ONCE);
		PlaySoundFX(cameraNode_,"Resources/Sounds/boom5.ogg");
	}

	
	void HandleDroneDestroyed(StringHash eventType, VariantMap& eventData)
	{
		playerScore_ += eventData["DronePoint"].GetInt();
		UpdateScoreDisplay();
	}
	
	
	void HandleCountFinished()
	{
		CreatePlayer();
		
		cameraNode_.GetChild("DirectionalLight").enabled = false;
		
		scene.updateEnabled = true;
		levelState_ = LS_INGAME;
		
		targetSprite_.visible = true;
		enemyCounterText_.text = 0;
		playerScoreText_.text = 0;
		
		renderer.viewports[0].renderPath.SetEnabled("Blur",false);
	}
	
	
	void HandleSoundGenerated(StringHash eventType, VariantMap& eventData)
	{
		Node@ soundNode = eventData["SoundNode"].GetPtr();
		String soundName = eventData["SoundName"].GetString();
		
		PlaySoundFX(soundNode, soundName);
	}
	
	
	void HandlePlayerDestroyed(StringHash eventType, VariantMap& eventData)
	{
		playerDestroyed_ = true;
		Vector3 camPosition = eventData["CamPosition"].GetVector3();
		Quaternion camRotation = eventData["CamRotation"].GetQuaternion();
		cameraNode_.worldRotation = camRotation;
		cameraNode_.worldPosition = camPosition;
		
		SetViewportCamera(cameraNode_.GetComponent("Camera"));
		cameraNode_.GetChild("DirectionalLight").enabled = true;
		SetSoundListener(cameraNode_);
	}
	
	
	void HandlePlayerHealthUpdate(StringHash eventType, VariantMap& eventData)
	{
		//Update Health
		float playerHealthFraction = eventData["CurrentHealthFraction"].GetFloat();
		
		int range = 512 - int( 512 * playerHealthFraction);
		healthFillSprite_.imageRect = IntRect(range, 0, 512 + range, 64);
		UpdateHealthTexture(playerHealthFraction);
	}
	
	
	void HandleFixedUpdate(StringHash eventType, VariantMap& eventData)
	{
		float timeStep = eventData["TimeStep"].GetFloat();
		float droneSpawnRate = 0.0;
			
		gamePhaseCounter_ += timeStep;
		if(gamePhaseCounter_ >= CRITICAL_PHASE)
		{
			droneSpawnRate = CRITICAL_PHASE_RATE;
			gamePhaseCounter_ = CRITICAL_PHASE;		
		}
		else if(gamePhaseCounter_ >= MODERATE_PHASE)
		{
			droneSpawnRate = MODERATE_PHASE_RATE;
		}
		else
		{
			droneSpawnRate = EASY_PHASE_RATE;
		}
		
		
		
		droneSpawnCounter_ +=timeStep;
		if(droneSpawnCounter_ >= droneSpawnRate)
		{
			if(GetDroneCount() < MAX_DRONE_COUNT)
			{
				SpawnDrone();
				UpdateDroneSprites();
				droneSpawnCounter_ = 0;
			}
		}
		
		
		spriteUpdateCounter_ += timeStep;
		
		if(spriteUpdateCounter_ >= SPRITE_UPDATE_TIME)
		{
			UpdateDroneSprites();
			spriteUpdateCounter_ = 0;
		}
		

	}
	
			
	void HandleLevelEvent(VariantMap& eventData)
	{
		int eventId = eventData["ID"].GetInt();
		
		switch(eventId)
		{
		case EVT_UPDATE:
			HandleUpdate(eventData);
			break;
		case EVT_KEYDOWN:
			HandleKeyDown(eventData);
			break;
		case EVT_MOUSEMOVE:
			HandleMouseMove(eventData);
			break;
		case EVT_MOUSECLICK:
			HandleMouseClick(eventData);
			break;	
		case EVT_SOUNDFINISH:
			HandleSoundFinish(eventData);
			break;	
		}
	}
	
	
	private void HandleUpdate(VariantMap& eventData)
	{
		if(playerDestroyed_ && levelState_ == LS_INGAME)
		{
			InitiateGameOver();
        }
	}
	
	void HandleKeyDown(VariantMap& eventData)
	{
		int key = eventData["key"].GetInt();	
		
		if(levelState_ == LS_OUTGAME)
		{
			HandleKeyOnOutGame(key);
		}
		else 
		{
			HandleKeyOnInGame(key);
		}
	}
	
	
	void HandleKeyOnOutGame(int key)
	{
		if(key == KEY_SPACE)
		{
			StartGame();
		}
	}

	void HandleKeyOnInGame(int key)
	{
		if(key == KEY_P)
		{
			PauseGame();
		}
	}
	
	
	void HandleMouseMove(VariantMap& eventData)
	{
		if(levelState_ != LS_INGAME)
		{
			return;
		}
		
		int dx = eventData["DX"].GetInt();
		int dy = eventData["DY"].GetInt();

		RotatePlayer(dx, dy);
	}
	
	
	
	void HandleMouseClick(VariantMap& eventData)
	{
		if(levelState_ != LS_INGAME)
		{
			return;
		}
		
		int mouseButton = eventData["Button"].GetInt();
		
		if(mouseButton == MOUSEB_LEFT)
		{
			Fire();
		}
	}
	
	
	void HandleSoundFinish(VariantMap& eventData)
	{	
		Node@ soundNode = eventData["Node"].GetPtr();
		soundNode.RemoveComponent("SoundSource3D");
	}
	

	void PlayBackgroundMusic(String musicName)
	{
		Sound@ musicFile = cache.GetResource("Sound",musicName);
		
		if(musicFile is null)
			return;
			
		musicFile.looped = true;
		backgroundMusicSource_.Play(musicFile);
	}
	
	
	void PlaySoundFX(Node@ soundNode, String soundName )
	{
		SoundSource3D@ source = soundNode.CreateComponent("SoundSource3D");
		
		Sound@ sound = cache.GetResource("Sound", soundName);
		source.SetDistanceAttenuation(0.2, 120, 0.1);
		source.soundType = SOUND_EFFECT;
		source.Play(sound);
	}
	
	
	void SpawnDrone()
	{
		Node@ droneNode = scene.CreateChild();
		
		XMLFile@ file = cache.GetResource("XMLFile", "Resources/Objects/LowLevelDrone.xml");
		droneNode.LoadXML(file.root);
		
		float nodeYaw = Random(360);
		droneNode.rotation = Quaternion(0,nodeYaw, 0);
		droneNode.Translate(Vector3(0,7,40));
		droneNode.vars["Sprite"] = CreateDroneSprite(NORMAL_DRONE_SPRITE);
	}


	Sprite@ CreateDroneSprite(String spriteTexture)
	{
		Texture2D@ droneSpriteTex = cache.GetResource("Texture2D", spriteTexture);
		Sprite@ droneSprite = radarScreenBase_.CreateChild("Sprite");
		
		droneSprite.texture = droneSpriteTex;
		droneSprite.SetSize(6,6);
		droneSprite.SetAlignment(HA_CENTER, VA_CENTER);
		droneSprite.SetHotSpot(3,3);
		droneSprite.blendMode = BLEND_ALPHA;
		droneSprite.priority = 1;
		
		return droneSprite;
	}
	

	
	void UpdateHealthTexture(float healthFraction)
	{
		if(healthFraction > 0.5)
		{
			healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_green.png");
		}
		else if(healthFraction > 0.2)
		{
			healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_yellow.png");
		}
		else
		{
			healthFillSprite_.texture = cache.GetResource("Texture2D", "Resources/Textures/health_bar_red.png");
		}
	}
	
	
	
	void UpdateDroneSprites()
	{
		Array<Node@> scriptNodes = scene.GetChildrenWithScript(true);
		int count = 0;
		
		for(uint i=0; i < scriptNodes.length ; i++)
		{
			Node@ droneNode = scriptNodes[i];
			Sprite@ nodeSprite = droneNode.vars["Sprite"].GetPtr();
			
			if(nodeSprite !is null)
			{
				Vector3 relativePos = droneNode.worldPosition - playerNode_.worldPosition ;
				nodeSprite.position = Vector2(relativePos.x, -(relativePos.z))* SCENE_TO_UI_SCALE;
				count += 1;
			}
		
		}
		
		enemyCounterText_.text = count;
		
	}
	

	void UpdateScoreDisplay()
	{
		playerScoreText_.text = playerScore_;
	}
	
	 
	void RotatePlayer(int dx, int dy)
	{
		VariantMap eventData;
		eventData["DX"] = dx;
		eventData["DY"] = dy;
		SendEvent("PlayerRotation", eventData);
		
		radarScreenBase_.rotation = -playerNode_.worldRotation.yaw;
	}

	
	void Fire()
	{	
		SendEvent("ActivateWeapon");
	}
	
	
	void PauseGame()
	{
		scene.updateEnabled = !scene.updateEnabled;
		
		if(scene.updateEnabled)
		{
			statusText_.text = "";
			levelState_ = LS_INGAME;
		}
		else
		{
			statusText_.text = "PAUSED";
			levelState_ = LS_PAUSED;
		}
		
		targetSprite_.visible = scene.updateEnabled;
	}
	
	int GetDroneCount()
	{
		Array<Node@> scriptNodes = scene.GetChildrenWithScript(true);
		int count = 0;
		
		for(uint i=0; i < scriptNodes.length ; i++)
		{
			Node@ droneNode = scriptNodes[i];
			Sprite@ nodeSprite = droneNode.vars["Sprite"].GetPtr();
			
			if(nodeSprite !is null)
			{
				count += 1;
			}

		}
		
		return count;
	}

	
}