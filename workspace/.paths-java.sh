export JAVA11_HOME=
export JAVA17_HOME=
export JAVA21_HOME=
export MAVEN_HOME=
export GRADLE_HOME=
export M2_HOME=$WORKSPACE_PATH/sdk/repositories/m2
export MAVEN_SETTINGS_FILE=

mkdir -p $M2_HOME

export PATH=$PATH:$MAVEN_HOME/bin:$GRADLE_HOME/bin

# Caching layer for dynamic Java build tool aliases
PATHS_GEN_SCRIPT="$WORKSPACE_PATH/.paths-java-generated.aliases.sh"

if [ ! -f "$PATHS_GEN_SCRIPT" ] || [ "$WORKSPACE_PATH/.paths-java.sh" -nt "$PATHS_GEN_SCRIPT" ]; then
    bash -c '
      GEN_FILE="$1"
      echo "# Auto-generated Java build tool aliases from .paths-java.sh" > "$GEN_FILE"
      
      _setup_java_aliases() {
          local jv="$1"
          local jhome_var="JAVA${jv}_HOME"
          eval "local jhome_val=\$$jhome_var"

          if [ -n "$jhome_val" ] && [ -d "$jhome_val" ]; then
              local mvn_cmd="mvn"
              if [ -n "$MAVEN_HOME" ] && [ -x "$MAVEN_HOME/bin/mvn" ]; then
                  mvn_cmd="$MAVEN_HOME/bin/mvn"
              fi

              if command -v "$mvn_cmd" >/dev/null 2>&1 || [ -x "$mvn_cmd" ]; then
                  if [ -n "$MAVEN_SETTINGS_FILE" ]; then
                      alias "mvn${jv}"="JAVA_HOME=\"$jhome_val\" $mvn_cmd -s \"$MAVEN_SETTINGS_FILE\""
                      alias "m${jv}"="JAVA_HOME=\"$jhome_val\" $mvn_cmd -s \"$MAVEN_SETTINGS_FILE\""
                  else
                      alias "mvn${jv}"="JAVA_HOME=\"$jhome_val\" $mvn_cmd"
                      alias "m${jv}"="JAVA_HOME=\"$jhome_val\" $mvn_cmd"
                  fi
              fi

              local gradle_cmd="gradle"
              if [ -n "$GRADLE_HOME" ] && [ -x "$GRADLE_HOME/bin/gradle" ]; then
                  gradle_cmd="$GRADLE_HOME/bin/gradle"
              fi

              if command -v "$gradle_cmd" >/dev/null 2>&1 || [ -x "$gradle_cmd" ]; then
                  alias "gradle${jv}"="JAVA_HOME=\"$jhome_val\" $gradle_cmd"
              fi
              
              alias "gw${jv}"="JAVA_HOME=\"$jhome_val\" ./gradlew"
              
              # Direct Java binary alias
              if [ -x "$jhome_val/bin/java" ]; then
                  alias "j${jv}"="\"$jhome_val/bin/java\""
              fi
          fi
      }

      for v in $(env | grep -Eo "^JAVA[0-9]+_HOME=" | grep -Eo "[0-9]+"); do
          _setup_java_aliases "$v"
      done
      
      # Now dump the specifically created aliases
      alias | grep -E "^alias (mvn|m|gradle|gw|j)[0-9]+=" >> "$GEN_FILE" 2>/dev/null
    ' _ "$PATHS_GEN_SCRIPT"
fi

source "$PATHS_GEN_SCRIPT"
